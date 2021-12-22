defmodule CuteFemBot.Tg.Watcher do
  @moduledoc """
  A service that watches for updates at Telegram and fires callback. May support
  both long-polling approach or webhook-based
  """

  use Supervisor

  alias __MODULE__.LongPolling

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init([:long_polling, interval: interval]) do
    children = [
      {LongPolling, [%LongPolling.Config{interval: interval}]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
