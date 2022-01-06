defmodule CuteFemBot.Telegram.Updater.Webhook.Listener do
  use Supervisor

  require Logger

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(%{dispatcher: dispatcher, config: config}) do
    port = Application.get_env(:cute_fem_bot, :port, 3000) |> String.to_integer()
    Logger.info("Starting Cowboy at #{port}")

    children = [
      {
        Plug.Cowboy,
        scheme: :http,
        plug: CuteFemBot.Telegram.Updater.Webhook.Listener.Router,
        options: [port: port]
      },
      {
        CuteFemBot.Telegram.Updater.Webhook.Listener.State,
        %{
          config: config,
          dispatcher: dispatcher
        }
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
