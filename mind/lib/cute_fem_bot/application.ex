defmodule CuteFemBot.Application do
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    handle_update_fun = fn update ->
      CuteFemBot.Logic.Handler.handle(CuteFemBot.Logic.Handler, update)
    end

    telegram = CuteFemBot.Telegram
    finch = CuteFemBot.Finch
    web_auth = CuteFemBotWeb.Auth
    bridge_cache = CuteFemBot.Server.Bridge.Cachex

    children = [
      CuteFemBot.Config.State,
      CuteFemBot.Repo,
      {web_auth, name: web_auth},
      CuteFemBotWeb.Endpoint,
      {Cachex, name: bridge_cache, limit: 100},
      {
        CuteFemBotWeb.Bridge,
        telegram: telegram, finch: finch, cache: bridge_cache, web_auth: web_auth
      },
      # dev_spec_once_web_auth_create_key(web_auth),
      {
        Finch,
        name: CuteFemBot.Finch
      },
      {
        Telegram.Api,
        name: telegram,
        config: %Telegram.Api.Config{
          finch: finch,
          token: fn -> CuteFemBot.Config.State.lookup!().api_token end
        }
      },
      {
        CuteFemBot.Logic.Stats,
        deps: %{
          telegram: telegram
        }
      },
      {
        CuteFemBot.Logic.Handler,
        name: CuteFemBot.Logic.Handler,
        deps: %{
          telegram: telegram,
          posting: CuteFemBot.Logic.Posting,
          web_auth: web_auth
        }
      },
      {
        CuteFemBot.Logic.Posting,
        name: CuteFemBot.Logic.Posting,
        deps: %{
          api: telegram
        }
      },
      {
        CuteFemBot.Logic.Tasks.SetCommands,
        deps: %{
          api: telegram
        }
      },
      {
        Telegram.Updater,
        [
          :long_polling,
          api: telegram,
          handler_fun: handle_update_fun,
          interval: fn -> CuteFemBot.Config.State.lookup!().long_polling_interval end
        ]
      }
    ]

    opts = [strategy: :one_for_one, name: CuteFemBot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # defp dev_spec_once_web_auth_create_key(web_auth) do
  #   {
  #     Task,
  #     fn ->
  #       {:ok, key, _} = CuteFemBotWeb.Auth.create_key(web_auth, 333)
  #       Logger.debug("Debug key: #{key}")
  #     end
  #   }
  # end

  # defp fatal_exit(message) do
  #   Logger.emergency(message)
  # end
end
