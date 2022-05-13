defmodule CuteFemBotWeb.Bridge do
  alias CuteFemBot.Repo
  alias CuteFemBot.Schema
  alias Telegram.Api
  alias CuteFemBotWeb.Bridge.IndexSuggestionsParams
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

  def index_suggestions(%IndexSuggestionsParams{} = params) do
    query =
      from(s in Schema.Suggestion,
        order_by: [desc: s.inserted_at]
      )
      |> IndexSuggestionsParams.apply_to_query(params)

    query =
      from(s in query,
        join: u in Schema.User,
        on: s.suggestor_id == u.id,
        select: {s, u}
      )

    {suggestions, users} =
      Repo.all(query)
      |> Enum.unzip()

    %{
      pagination: params.pagination,
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

  def get_cors_origins() do
    %{www: www} = GenServer.call(__MODULE__, :get_cors)
    [www]
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
  def handle_call({:get_file, file_id}, _, state) do
    {:reply, get_file_reply(state, file_id), state}
  end

  @impl true
  def handle_call({:lookup_auth, key}, _, %{web_auth: auth} = state) do
    result = CuteFemBotWeb.Auth.lookup(auth, key)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:get_cors, _, %{config: cfg} = state) do
    %CuteFemBot.Config{www_path: www} = CuteFemBot.Config.State.lookup!(cfg)

    {:reply, %{www: www}, state}
  end

  defp get_file_reply(state, file_id) do
    with {:ok, %Finch.Response{} = resp} <- try_get_file_response(state, file_id) do
      content_type =
        case try_find_mime_type(file_id) do
          nil -> CuteFemBotWeb.Bridge.Util.extract_content_type_header(resp)
          x -> x
        end

      {:ok, content_type, resp.body}
    else
      {:error, :unavailable} = err -> err
      x -> x
    end
  end

  defp try_get_file_response(
         %{
           telegram: tg,
           config: cfg,
           finch: finch,
           cache: cache
         },
         file_id
       ) do
    err_unavailable = fn -> {:error, :unavailable} end

    case lookup_file_in_cache(cache, file_id) do
      {:ok, :unavailable} ->
        err_unavailable.()

      {:ok, %Finch.Response{}} = x ->
        x

      :error ->
        with {:ok, path} <- get_file_download_path_from_telegram(tg, file_id),
             %CuteFemBot.Config{api_token: token} = CuteFemBot.Config.State.lookup!(cfg),
             url = Telegram.Util.href_file(token, path),
             {:ok, %Finch.Response{} = resp} <- download_file(finch, url) do
          put_file_into_cache(cache, file_id, resp)
          {:ok, resp}
        else
          {:error, :file_is_unavailable} ->
            put_file_into_cache(cache, file_id, :unavailable)
            err_unavailable.()

          x ->
            x
        end
    end
  end

  defp get_file_download_path_from_telegram(tg, file_id) do
    just_some_err = fn -> {:error, "Failed to get file path from Telegram"} end

    case Api.request(tg, method_name: "getFile", body: %{"file_id" => file_id}) do
      {:ok, %{"file_path" => path}} ->
        {:ok, path}

      {:error, {:telegram, description}} ->
        # maybe there is no reason to try?
        if description =~ ~r{wrong file_id or the file is temporarily unavailable} do
          {:error, :file_is_unavailable}
        else
          just_some_err.()
        end

      {:error, _} ->
        just_some_err.()
    end
  end

  defp download_file(finch, url) do
    case Finch.build(:get, url) |> Finch.request(finch) do
      {:ok, %Finch.Response{}} = x -> x
      {:error, _} -> {:error, "Failed to download file"}
    end
  end

  defp try_find_mime_type(file_id) do
    Repo.one(from(s in Schema.Suggestion, where: s.file_id == ^file_id, select: s.file_mime_type))
  end

  defp lookup_file_in_cache(cache, file_id) do
    case Cachex.get!(cache, {:file, file_id}) do
      nil -> :error
      data -> {:ok, data}
    end
  end

  defp put_file_into_cache(cache, file_id, data) do
    Cachex.put(cache, {:file, file_id}, data)
  end
end
