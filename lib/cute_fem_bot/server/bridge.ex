defmodule CuteFemBot.Server.Bridge do
  alias CuteFemBot.Repo
  alias CuteFemBot.Schema
  alias Telegram.Api

  import Ecto.Query

  require Logger

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    {:ok,
     %{
       telegram: Keyword.fetch!(opts, :telegram),
       finch: Keyword.fetch!(opts, :finch),
       config: Keyword.fetch!(opts, :config),
       cache: Keyword.fetch!(opts, :cache)
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

  # Client API

  def get_file(file_id) do
    GenServer.call(__MODULE__, {:get_file, file_id}, 300_000)
  end

  def get_queue() do
    Repo.all(from(s in Schema.Suggestion, where: not is_nil(s.decision)))
  end
end
