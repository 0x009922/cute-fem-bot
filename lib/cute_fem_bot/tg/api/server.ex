defmodule CuteFemBot.Tg.Api.Server do
  use GenServer

  alias CuteFemBot.Tg.Api

  def start_link(%Api.Config{} = cfg) do
    GenServer.start_link(__MODULE__, cfg, name: __MODULE__)
  end

  ## Callbacks

  @impl true
  def init(%Api.Config{} = cfg) do
    {:ok, cfg}
  end

  @impl true
  def handle_call({:get_updates, params}, _from, cfg) do
    {:reply, Api.get_updates(cfg, params), cfg}
  end

  def get_updates(params \\ nil) do
    GenServer.call(__MODULE__, {:get_updates, params})
  end
end
