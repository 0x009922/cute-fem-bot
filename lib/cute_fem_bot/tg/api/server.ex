defmodule CuteFemBot.Tg.Api.Server do
  use GenServer

  alias CuteFemBot.Tg.Api
  alias __MODULE__, as: Self

  def start_link(%Api.Config{} = cfg) do
    GenServer.start_link(Self, cfg, name: Self)
  end

  ## Callbacks

  @impl true
  def init(%Api.Config{} = cfg) do
    {:ok, cfg}
  end

  @impl true
  def handle_call({method, params}, _from, cfg) do
    {:reply, apply(Api, method, [cfg, params]), cfg}
  end

  def call(method, params) do
    GenServer.call(Self, {method, params})
  end
end
