defmodule CuteFemBot.Server.Router do
  use Plug.Router, init_mode: :runtime
  alias CuteFemBot.Server.Bridge

  if Mix.env() == :dev do
    use Plug.Debugger, otp_app: :cute_fem_bot
  end

  plug(Plug.Logger)
  plug(:match)

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Poison
  )

  plug(:dispatch)

  get "/queue" do
    conn
    |> send_json_resp(Bridge.get_queue())
  end

  # get "/test" do
  #   IO.inspect(opts, label: "test opts")
  # end

  get "/file/:file_id" do
    {content_type, data} = Bridge.get_file(file_id)

    conn
    |> put_resp_content_type(content_type)
    |> send_resp(200, data)
  end

  # post "/webhook/:token" do
  #   %{"token" => path_token} = conn.path_params
  #   %CuteFemBot.Config{api_token: original_token} = State.get_config()

  #   if path_token == original_token do
  #     update = conn.body_params
  #     State.dispatch_update(update)
  #     send_resp(conn, 200, "ok")
  #   else
  #     send_resp(conn, 404, "wrong token")
  #   end
  # end

  match _ do
    send_resp(conn, 404, "oops")
  end

  defp send_json_resp(conn, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(data))
  end
end
