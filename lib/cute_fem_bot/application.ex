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
          fatal_exit("Unable to read config: #{inspect(err)}")
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
      updater_spec(%{
        api: CuteFemBot.Telegram.Api,
        config: CuteFemBot.Config.State,
        handler_fun: handle_update_fun
      })
    ]

    opts = [strategy: :one_for_one, name: CuteFemBot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp updater_spec(%{api: api, config: config, handler_fun: handler}) do
    case Application.get_env(:cute_fem_bot, :update_approach, "long-polling") do
      "long-polling" ->
        {
          CuteFemBot.Telegram.Updater,
          [
            :long_polling,
            interval: 1_000,
            handler_fun: handler,
            api: api
          ]
        }

      "webhook" ->
        {
          CuteFemBot.Telegram.Updater,
          [
            :webhook,
            deps: %{
              api: api,
              config: config
            },
            handler_fun: handler
          ]
        }

      invalid ->
        fatal_exit("Invalid update_approach param: #{inspect(invalid)}")
    end
  end

  defp fatal_exit(message) do
    Logger.emergency(message)
  end

  # doesn't work btw

  # @impl true
  # def prep_stop(_) do
  #   CuteFemBot.Persistence.Saver.save_immediately(CuteFemBot.Persistence.Saver)
  #   :ok
  # end
end
