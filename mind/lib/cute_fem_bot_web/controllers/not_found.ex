defmodule CuteFemBotWeb.Controllers.NotFound do
  use CuteFemBotWeb, :controller
  import Plug.Conn

  def show(conn, _) do
    conn
    |> send_resp(404, "Not found т_т")
  end
end
