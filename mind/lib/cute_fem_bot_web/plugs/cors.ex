defmodule CuteFemBotWeb.Plugs.CORS do
  import Plug.Conn

  def init(x), do: x

  def call(%Plug.Conn{} = conn, _) do
    %{www: www} = CuteFemBotWeb.Bridge.get_cors_data()

    conn =
      if www do
        conn
        |> put_resp_header("access-control-allow-origin", www)
        |> put_resp_header("access-control-allow-methods", "*")
      else
        conn
      end

    case conn do
      %Plug.Conn{method: :options} -> send_resp(conn, 204, "")
      _ -> conn
    end
  end
end
