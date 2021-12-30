defmodule CuteFemBot.Application do
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

    handle_update_fun = fn update ->
      CuteFemBot.Logic.Handler.handle(CuteFemBot.Logic.Handler, update)
    end

    children = [
      {CuteFemBot.Config.State, [cfg, name: CuteFemBot.Config.State]},
      {CuteFemBot.Persistence, name: CuteFemBot.Persistence},
      {
        CuteFemBot.Persistence.Saver,
        persistence: CuteFemBot.Persistence, name: CuteFemBot.Persistence.Saver
      },
      {
        CuteFemBot.Telegram.Api.Supervisor,
        api: CuteFemBot.Telegram.Api, config: CuteFemBot.Config.State
      },
      {
        CuteFemBot.Logic.Handler,
        name: CuteFemBot.Logic.Handler,
        api: CuteFemBot.Telegram.Api,
        persistence: CuteFemBot.Persistence,
        config: CuteFemBot.Config.State,
        posting: CuteFemBot.Logic.Posting
      },
      {
        CuteFemBot.Logic.Posting,
        name: CuteFemBot.Logic.Posting,
        deps: %{
          api: CuteFemBot.Telegram.Api,
          persistence: CuteFemBot.Persistence,
          config: CuteFemBot.Config.State
        }
      },
      {
        CuteFemBot.Logic.Tasks.SetCommands,
        deps: %{
          api: CuteFemBot.Telegram.Api,
          config: CuteFemBot.Config.State
        }
      },
      {
        CuteFemBot.Telegram.Updater,
        [
          :long_polling,
          interval: 1_000,
          handler_fun: handle_update_fun,
          api: CuteFemBot.Telegram.Api
        ]
      }
    ]

    opts = [strategy: :one_for_one, name: CuteFemBot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # doesn't work btw

  # @impl true
  # def prep_stop(_) do
  #   CuteFemBot.Persistence.Saver.save_immediately(CuteFemBot.Persistence.Saver)
  #   :ok
  # end
end
