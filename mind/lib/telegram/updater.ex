defmodule Telegram.Updater do
  @moduledoc """
  A service that watches for updates at Telegram and fires callback. May support
  both long-polling approach or webhook-based (TODO)
  """

  use Supervisor

  alias __MODULE__.LongPolling
  alias Telegram.Dispatcher

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init([:long_polling | opts]) do
    interval = Keyword.fetch!(opts, :interval)
    handler = Keyword.fetch!(opts, :handler_fun)

    children = [
      {LongPolling,
       [
         %LongPolling.Config{
           interval: interval,
           dispatcher: Dispatcher,
           api: Keyword.fetch!(opts, :api)
         }
       ]},
      {Dispatcher, [handler, name: Dispatcher]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def init([:webhook | _opts]) do
    raise "WebHook-based updater is not supported (yet)"

    # deps = Keyword.fetch!(opts, :deps)
    # handler = Keyword.fetch!(opts, :handler_fun)

    # children = [
    #   {Telegram.Updater.Webhook.TaskSet, deps: deps},
    #   {
    #     Telegram.Updater.Webhook.Listener,
    #     %{
    #       config: deps.config,
    #       dispatcher: Dispatcher
    #     }
    #   },
    #   {Dispatcher, [handler, name: Dispatcher]}
    # ]

    # Supervisor.init(children, strategy: :one_for_one)
  end
end
