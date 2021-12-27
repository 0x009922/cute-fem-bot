defmodule CuteFemBot.Logic.Handler do
  @moduledoc """
  Main handler for incoming telegram updates
  """

  # impl of Telegram Handler

  @behaviour CuteFemBot.Telegram.Handler

  @impl true
  def handle_update(update) do
    CuteFemBot.Logic.Handler |> GenServer.cast({:handle_update, update})
  end

  # impl GenServer

  use GenServer

  @impl true
  def init(opts) do
    persistence = Keyword.fetch!(opts, :persistence)
    api = Keyword.fetch!(opts, :telegram_api)

    {:ok, %{persistence: persistence, api: api}}
  end

  @impl true
  def handle_cast({:handle_update, update}, state) do
    CtxHandler.handle(CuteFemBot.Logic.Handler.Middleware, Map.merge(state, %{update: update}))

    {:noreply, state}
  end
end
