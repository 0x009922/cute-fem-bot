defmodule CuteFemBot.Telegram.Updater.LongPolling do
  @moduledoc """
  It is a supervisable service that fetches updates from Telegram with Long-Polling approach
  """

  require Logger

  use Supervisor

  alias CuteFemBot.Telegram.Updater.LongPolling
  alias LongPolling.Config
  alias LongPolling.Poller

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init([%Config{} = cfg]) do
    Logger.info("Starting long-polling service with config: #{inspect(cfg)}")

    children = [
      %{
        id: Poller,
        start: {Poller, :start_link, [cfg]}
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
