defmodule CuteFemBot.Telegram.Updater.Webhook.Listener.State do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_config() do
    GenServer.call(__MODULE__, :get_config)
  end

  def dispatch_update(update) do
    GenServer.cast(__MODULE__, {:dispatch_update, update})
  end

  @impl true
  def init(
        %{
          config: _config,
          dispatcher: _dispatcher
        } = deps
      ) do
    {:ok, deps}
  end

  @impl true
  def handle_call(:get_config, _, deps) do
    conf = CuteFemBot.Config.State.get(deps.config)
    {:reply, conf, deps}
  end

  @impl true
  def handle_cast({:dispatch_update, update}, deps) do
    CuteFemBot.Telegram.Dispatcher.dispatch_incoming_updates(deps.dispatcher, [update])
    {:noreply, deps}
  end
end
