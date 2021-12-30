defmodule CuteFemBot.Logic.Handler do
  use GenServer

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
    {:ok, _} =
      CtxHandler.handle(CuteFemBot.Logic.Handler.Middleware, Map.merge(state, %{update: update}))

    {:noreply, state}
  end

  def handle(handler, update) do
    GenServer.cast(handler, {:handle_update, update})
  end
end
