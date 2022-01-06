defmodule CuteFemBot.Telegram.Updater.Webhook.Listener.Router do
  use Plug.Router

  alias CuteFemBot.Telegram.Updater.Webhook.Listener.State

  plug(Plug.Logger)
  plug(:match)

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: JSON
  )

  plug(:dispatch)

  post "/webhook/:token" do
    %{"token" => path_token} = conn.path_params
    %CuteFemBot.Config{api_token: original_token} = State.get_config()

    if path_token == original_token do
      update = conn.body_params
      State.dispatch_update(update)
      send_resp(conn, 200, "ok")
    else
      send_resp(conn, 404, "wrong path")
    end
  end

  match _ do
    send_resp(conn, 404, "oops")
  end
end
