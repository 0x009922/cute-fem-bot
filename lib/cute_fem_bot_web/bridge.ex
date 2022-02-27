defmodule CuteFemBotWeb.Bridge do
  alias CuteFemBot.Repo
  alias CuteFemBot.Schema
  alias Telegram.Api
  import Ecto.Query
  require Logger
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Client API

  def get_file(file_id) do
    GenServer.call(__MODULE__, {:get_file, file_id}, 300_000)
  end

  def index_suggestions(params \\ []) do
    only_with_decision? = Keyword.get(params, :only_with_decision, false)

    query =
      from(s in Schema.Suggestion,
        join: u in Schema.User,
        on: s.suggestor_id == u.id,
        select: {s, u}
      )

    query =
      if only_with_decision? do
        from(s in query, where: not is_nil(s.decision))
      else
        query
      end

    {suggestions, users} =
      Repo.all(query)
      |> Enum.unzip()

    %{
      suggestions: suggestions,
      users:
        Stream.uniq_by(users, fn %{id: id} -> id end)
        |> Enum.map(fn %Schema.User{} = user ->
          %{
            id: user.id,
            banned: user.banned,
            meta: Schema.User.decode_meta(user)
          }
        end)
    }
  end

  def update_suggestion(file_id, params) do
    with {:ok, %Schema.Suggestion{} = item} <- find_suggestion(file_id),
         {:ok, _} <- update_suggestion_with_formatting(item, params) do
      :ok
    end
  end

  def lookup_auth_key(key) do
    GenServer.call(__MODULE__, {:lookup_auth, key})
  end

  defp find_suggestion(file_id) do
    case Repo.one(from(s in Schema.Suggestion, where: s.file_id == ^file_id)) do
      nil -> {:error, "Suggestion not found"}
      x -> {:ok, x}
    end
  end

  defp update_suggestion_with_formatting(item, params) do
    case item |> Schema.Suggestion.changeset_web(params) |> Repo.update() do
      {:ok, _} = x -> x
      {:error, changeset} -> {:error, format_changeset_errors(changeset)}
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Map.to_list()
    |> Stream.map(fn {key, errors} ->
      errors = Enum.join(errors, "; ")
      "#{key}: #{errors}"
    end)
    |> Enum.join("; ")
  end

  # Server callbacks

  @impl true
  def init(opts) do
    {:ok,
     %{
       telegram: Keyword.fetch!(opts, :telegram),
       finch: Keyword.fetch!(opts, :finch),
       config: Keyword.fetch!(opts, :config),
       cache: Keyword.fetch!(opts, :cache),
       web_auth: Keyword.fetch!(opts, :web_auth)
     }}
  end

  @impl true
  def handle_call(
        {:get_file, file_id},
        _,
        %{
          telegram: tg,
          config: cfg,
          finch: finch,
          cache: cache
        } = state
      ) do
    %{"file_path" => path} =
      Api.request!(tg, method_name: "getFile", body: %{"file_id" => file_id})

    %CuteFemBot.Config{api_token: token} = CuteFemBot.Config.State.lookup!(cfg)
    url = Telegram.Util.href_file(token, path)

    resp = load_file_with_caching(cache, finch, url)

    content_type =
      case try_find_mime_type(file_id) do
        nil -> Keyword.fetch!(resp.headers, "content-type")
        x -> x
      end

    IO.inspect(resp, label: "resp")
    IO.inspect(content_type, label: "type")

    {:reply, {content_type, resp.body}, state}
  end

  @impl true
  def handle_call({:lookup_auth, key}, _, %{web_auth: auth} = state) do
    result = CuteFemBot.Logic.WebAuth.lookup(auth, key)
    {:reply, result, state}
  end

  defp try_find_mime_type(file_id) do
    Repo.one(from(s in Schema.Suggestion, where: s.file_id == ^file_id, select: s.file_mime_type))
  end

  defp load_file_with_caching(cache, finch, url) do
    case Cachex.get!(cache, {:file, url}) do
      nil ->
        {:ok, %Finch.Response{} = resp} = Finch.build(:get, url) |> Finch.request(finch)
        Logger.debug("Putting data to cache")
        Cachex.put(cache, {:file, url}, resp)
        resp

      %Finch.Response{} = resp ->
        resp
    end
  end
end
