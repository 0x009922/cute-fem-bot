defmodule CuteFemBot.Logic.Handler do
  use GenServer

  alias __MODULE__.Entry
  alias __MODULE__.Ctx
  alias CuteFemBot.Telegram.Api
  alias CuteFemBot.Telegram.Types.Message

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
    case CtxHandler.handle(Entry, Ctx.new(state.deps, update)) do
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

  defp handle_error(deps, %CtxHandler.State{} = state, err, trace) do
    err_formatted = Exception.format(:error, err, trace)
    err_formatted_escaped = err_formatted |> CuteFemBot.Util.escape_html()
    state_path_formatted = inspect(state.path)
    Logger.error("Error during update handling: #{err_formatted} | path: #{state_path_formatted}")

    inspect_data =
      inspect(
        %{
          state_path: state.path
        },
        pretty: true,
        syntax_colors: []
      )
      |> CuteFemBot.Util.escape_html()

    text = """
    Хозяин, у меня ошибка во время обработки апдейта.

    Ошибка: <pre>#{err_formatted_escaped}</pre>

    <pre><code class=\"language-elixir\">#{inspect_data}</code></pre>
    """

    %CuteFemBot.Config{master: chat_id} = CuteFemBot.Config.State.lookup!(deps.config)

    {:ok, _} =
      Api.send_message(
        deps.api,
        Message.with_text(text) |> Message.set_chat_id(chat_id) |> Message.set_parse_mode("html")
      )
  end
end
