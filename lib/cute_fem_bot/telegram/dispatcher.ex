defmodule CuteFemBot.Telegram.Dispatcher do
  @moduledoc """
  Supervisable server that dispatches updates to the passed handler.
  """

  use GenServer

  @impl true
  def init(opts) do
    handler_mod = Keyword.fetch!(opts, :handler_module)

    {:ok, handler_mod}
  end

  @impl true
  def handle_cast({:dispatch_incoming_updates, updates}, handler_mod) do
    # it is possible here to make basic handling e.g. group messages from a single media group
    Enum.each(updates, fn x -> apply(handler_mod, :handle_update, [x]) end)

    {:no_reply, handler_mod}
  end

  def dispatch_incoming_updates(dispatcher, updates) do
    GenServer.cast(dispatcher, {:dispatch_incoming_updates, updates})
  end
end
