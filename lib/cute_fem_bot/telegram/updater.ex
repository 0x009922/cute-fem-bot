defmodule CuteFemBot.Telegram.Updater do
  @moduledoc """
  A service that watches for updates at Telegram and fires callback. May support
  both long-polling approach or webhook-based
  """

  use Supervisor

  alias __MODULE__.LongPolling
  alias CuteFemBot.Telegram.Dispatcher

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init([:long_polling | opts]) do
    interval = Keyword.fetch!(opts, :interval)
    handler = Keyword.fetch!(opts, :handler)

    children = [
      {Dispatcher, [handler]},
      {LongPolling, [%LongPolling.Config{interval: interval, dispatcher: Dispatcher}]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
