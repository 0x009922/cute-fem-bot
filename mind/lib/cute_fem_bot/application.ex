defmodule CuteFemBot.Application do
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    cfg =
      case CuteFemBot.Config.read_cfg() do
        {:ok, %CuteFemBot.Config{} = cfg} ->
          Logger.debug("Loaded config: #{inspect(cfg)}")
          cfg

        {:error, err} ->
          fatal_exit("Unable to read config: #{inspect(err)}")
      end

    {:ok, cfg_ref} = CuteFemBot.Config.State.init(cfg)

    handle_update_fun = fn update ->
      CuteFemBot.Logic.Handler.handle(CuteFemBot.Logic.Handler, update)
    end

    telegram = CuteFemBot.Telegram
    finch = CuteFemBot.Finch
    web_auth = CuteFemBotWeb.Auth
    bridge_cache = CuteFemBot.Server.Bridge.Cachex

    children = [
      CuteFemBot.Repo,
      {web_auth, name: web_auth},
      CuteFemBotWeb.Endpoint,
      {Cachex, name: bridge_cache, limit: 100},
      {
        CuteFemBotWeb.Bridge,
        telegram: telegram, config: cfg_ref, finch: finch, cache: bridge_cache, web_auth: web_auth
      },
      # {
      #   Task,
      #   fn ->
      #     {:ok, key, _} = CuteFemBot.Logic.WebAuth.create_key(web_auth, 333)
      #     Logger.debug("Debug key: #{key}")
      #   end
      # }
      {
        Finch,
        name: CuteFemBot.Finch
      },
      {
        Telegram.Api,
        name: telegram,
        config: %Telegram.Api.Config{
          finch: finch,
          token: cfg.api_token
        }
      },
      {
        CuteFemBot.Logic.Stats,
        deps: %{
          telegram: telegram,
          cfg: cfg_ref
        }
      },
      {
        CuteFemBot.Logic.Handler,
        name: CuteFemBot.Logic.Handler,
        deps: %{
          api: telegram,
          config: cfg_ref,
          posting: CuteFemBot.Logic.Posting,
          web_auth: web_auth
        }
      },
      {
        CuteFemBot.Logic.Posting,
        name: CuteFemBot.Logic.Posting,
        deps: %{
          api: telegram,
          config: cfg_ref
        }
      },
      {
        CuteFemBot.Logic.Tasks.SetCommands,
        deps: %{
          api: telegram,
          config: cfg_ref
        }
      },
      updater_spec(%{
        api: telegram,
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
          Telegram.Updater,
          [
            :long_polling,
            interval: lp_interval,
            handler_fun: handler,
            api: api
          ]
        }

      :webhook ->
        {
          Telegram.Updater,
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
