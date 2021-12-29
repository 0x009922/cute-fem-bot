defmodule CuteFemBot.Telegram.Dispatcher do
  @moduledoc """
  Supervisable server that dispatches updates to the passed handler.
  """

  use GenServer

  def start_link([handler | opts]) do
    GenServer.start_link(__MODULE__, handler, opts)
  end

  @impl true
  def init(handler_fun) do
    {:ok, handler_fun}
  end

  @impl true
  def handle_cast({:dispatch_incoming_updates, updates}, handler_fun) do
    # it is possible here to make basic handling e.g. group messages from a single media group
    Enum.each(updates, fn x ->
      IO.inspect(x, label: "update")
      handler_fun.(x)
    end)

    {:noreply, handler_fun}
  end

  def dispatch_incoming_updates(name, updates) do
    GenServer.cast(name, {:dispatch_incoming_updates, updates})
  end
end
