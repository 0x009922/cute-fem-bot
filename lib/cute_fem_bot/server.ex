defmodule CuteFemBot.Server do
  use Supervisor

  require Logger

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_) do
    port = Application.get_env(:cute_fem_bot, :port, 3000)
    Logger.info("Cowboy is going to listed: #{port}")

    children = [
      {
        Plug.Cowboy,
        scheme: :http, plug: {CuteFemBot.Server.Router, {:some, :opts}}, options: [port: port]
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
