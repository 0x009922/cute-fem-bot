defmodule CuteFemBotWeb.Controllers.Health do
  use CuteFemBotWeb, :controller

  def index(conn, _) do
    conn
    |> send_resp(200, "^_^")
  end
end
