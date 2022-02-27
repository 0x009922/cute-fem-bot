defmodule CuteFemBotWeb.Controllers.Auth do
  use CuteFemBotWeb, :controller

  def show(%Plug.Conn{assigns: %{auth: {_user_id, expires_at}}} = conn, _) do
    json(conn, %{expires_at: expires_at})
  end
end
