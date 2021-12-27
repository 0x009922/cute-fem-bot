defmodule CuteFemBot.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    cfg =
      case CuteFemBot.Config.read_cfg() do
        {:ok, cfg} ->
          Logger.debug("Loaded config: #{inspect(cfg)}")
          cfg

        {:error, err} ->
          Logger.emergency("Unable to read config: #{inspect(err)}")
          System.stop(1)
      end

    children = [
      # {CuteFemBot.Config.State, [cfg]},
      {CuteFemBot.Telegram.Api.Supervisor, [cfg]}
      # {CuteFemBot.Telegram.Updater, [:long_polling, interval: 5_000, handler: nil]}
      # {CuteFemBot.Logic.Handler, persistence: nil, telegram_api: nil}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CuteFemBot.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
