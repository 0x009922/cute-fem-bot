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

    {:ok, cfg_ref} = CuteFemBot.Config.State.init(cfg)

    handle_update_fun = fn update ->
      CuteFemBot.Logic.Handler.handle(CuteFemBot.Logic.Handler, update)
    end

    children = [
      CuteFemBot.Repo,
      {
        CuteFemBot.Telegram.Api.Supervisor,
        api: CuteFemBot.Telegram.Api, config: cfg_ref
      },
      {
        CuteFemBot.Logic.Handler,
        name: CuteFemBot.Logic.Handler,
        api: CuteFemBot.Telegram.Api,
        config: cfg_ref,
        posting: CuteFemBot.Logic.Posting
      },
      {
        CuteFemBot.Logic.Posting,
        name: CuteFemBot.Logic.Posting,
        deps: %{
          api: CuteFemBot.Telegram.Api,
          config: cfg_ref
        }
      },
      {
        CuteFemBot.Logic.Tasks.SetCommands,
        deps: %{
          api: CuteFemBot.Telegram.Api,
          config: cfg_ref
        }
      },
      updater_spec(%{
        api: CuteFemBot.Telegram.Api,
        config: cfg_ref,
        handler_fun: handle_update_fun
      })
    ]

    opts = [strategy: :one_for_one, name: CuteFemBot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp updater_spec(%{api: api, config: cfg_ref, handler_fun: handler}) do
    %CuteFemBot.Config{long_polling_interval: lp_interval, updates_approach: approach} =
      CuteFemBot.Config.State.lookup!(cfg_ref)

    case approach do
      :long_polling ->
        {
          CuteFemBot.Telegram.Updater,
          [
            :long_polling,
            interval: lp_interval,
            handler_fun: handler,
            api: api
          ]
        }

      :webhook ->
        {
          CuteFemBot.Telegram.Updater,
          [
            :webhook,
            deps: %{
              api: api,
              config: cfg_ref
            },
            handler_fun: handler
          ]
        }
    end
  end

  defp fatal_exit(message) do
    Logger.emergency(message)
  end
end
