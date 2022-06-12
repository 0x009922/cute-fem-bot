defmodule CuteFemBot.Logic.Handler do
  use GenServer

  alias CuteFemBot.Logic.Handler, as: Self
  # alias __MODULE__.Entry
  # alias __MODULE__.Ctx
  alias Telegram.Api
  alias Telegram.Types.Message

  require Logger

  def start_link(opts) do
    gen_opts = Keyword.take(opts, [:name])
    init_opts = Keyword.fetch!(opts, :deps)

    GenServer.start_link(__MODULE__, init_opts, gen_opts)
  end

  @impl true
  def init(deps) do
    {
      :ok,
      %{
        deps: deps
      }
    }
  end

  @impl true
  def handle_cast({:handle_update, update}, state) do
    init_ctx =
      Traffic.Context.new()
      |> Self.Context.put_raw_update(update)
      |> Self.Context.put_deps(state.deps)

    case Traffic.run(init_ctx, [Self.Entry]) do
      {:ok, _} ->
        nil

      {:error, any_error} ->
        handle_error(state.deps, any_error)
    end

    {:noreply, state}
  end

  def handle(handler, update) do
    GenServer.cast(handler, {:handle_update, update})
  end

  defp handle_error(deps, any_error) do
    err_inspect = inspect(any_error)

    Logger.error("Handler error: #{err_inspect}")

    err_escaped = err_inspect |> CuteFemBot.Util.escape_html()

    text = """
    Хозяин, у меня ошибка во время обработки апдейта.

    Ошибка: <pre>#{err_escaped}</pre>
    """

    %CuteFemBot.Config{master: chat_id} = CuteFemBot.Config.State.lookup!(deps.config)

    {:ok, _} =
      Api.send_message(
        deps.api,
        Message.with_text(text) |> Message.set_chat_id(chat_id) |> Message.set_parse_mode("html")
      )
  end
end
