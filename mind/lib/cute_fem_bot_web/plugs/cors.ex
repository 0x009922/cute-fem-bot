defmodule CuteFemBotWeb.Plugs.CORS do
  import Plug.Conn

  def init(x), do: x

  def call(conn, _) do
    %{www: www} = CuteFemBotWeb.Bridge.get_cors_data()

    if www do
      conn
      |> put_resp_header("access-control-allow-origin", www)
    else
      conn
    end
  end
end
