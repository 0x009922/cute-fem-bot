defmodule CuteFemBotWeb.Controllers.NotFound do
  use CuteFemBotWeb, :controller
  import Plug.Conn

  def show(conn, _) do
    conn
    |> put_status(404)
    |> text("Not found т_т")
  end
end
