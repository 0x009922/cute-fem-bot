defmodule CuteFemBot.Logic.Handler do
  use GenServer

  alias __MODULE__.Middleware
  alias __MODULE__.Ctx
  alias CuteFemBot.Telegram.Api
  alias CuteFemBot.Telegram.Types.Message
  alias CuteFemBot.Config

  require Logger

  def start_link(opts) do
    gen_opts = Keyword.take(opts, [:name])
    init_opts = Keyword.take(opts, [:api, :persistence, :config, :posting])

    GenServer.start_link(__MODULE__, init_opts, gen_opts)
  end

  @impl true
  def init(init_opts) do
    {
      :ok,
      %{
        deps: %{
          api: Keyword.fetch!(init_opts, :api),
          persistence: Keyword.fetch!(init_opts, :persistence),
          config: Keyword.fetch!(init_opts, :config),
          posting: Keyword.fetch!(init_opts, :posting)
        }
      }
    }
  end

  @impl true
  def handle_cast({:handle_update, update}, state) do
    case CtxHandler.handle(Middleware, Ctx.new(state.deps, update)) do
      {:ok, _} ->
        nil

      {:error, :raised, err, trace, handler_state} ->
        handle_error(state.deps, handler_state, err, trace)
    end

    {:noreply, state}
  end

  def handle(handler, update) do
    GenServer.cast(handler, {:handle_update, update})
  end

  defp handle_error(deps, state, err, trace) do
    err_formatted = Exception.format(:error, err, trace)
    state_path_formatted = inspect(state.path)
    Logger.error("Error during update handling: #{err_formatted} | path: #{state_path_formatted}")

    inspect_data =
      inspect(
        %{
          state: state,
          error: err
        },
        pretty: true,
        syntax_colors: []
      )
      |> CuteFemBot.Util.escape_html()

    text = """
    Хозяин, у меня ошибка во время обработки апдейта.

    <pre>#{inspect_data}</pre>
    """

    %Config{master_chat_id: chat_id} = Config.State.get(deps.config)

    {:ok, _} =
      Api.send_message(
        deps.api,
        Message.with_text(text) |> Message.set_chat_id(chat_id) |> Message.set_parse_mode("html")
      )
  end
end
