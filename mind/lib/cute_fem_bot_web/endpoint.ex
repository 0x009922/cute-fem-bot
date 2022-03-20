defmodule CuteFemBotWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :cute_fem_bot

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  # @session_options [
  #   store: :cookie,
  #   key: "_testing_key",
  #   signing_salt: "sdT7EXJm"
  # ]

  # socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  # plug(Plug.Static,
  #   at: "/",
  #   from: :testing,
  #   gzip: false,
  #   only: ~w(assets fonts images favicon.ico robots.txt)
  # )

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.RequestId)
  # plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(CuteFemBotWeb.Plugs.CORS)
  # plug(Plug.Session, @session_options)
  plug(CuteFemBotWeb.Router)
end
