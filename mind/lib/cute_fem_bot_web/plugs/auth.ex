defmodule CuteFemBotWeb.Plugs.Auth do
  import Plug.Conn
  require Logger

  def init(x), do: x

  def call(conn, _) do
    data =
      case get_req_header(conn, "authorization") do
        [key] ->
          case CuteFemBotWeb.Bridge.lookup_auth_key(key) do
            nil ->
              Logger.debug("Key not found")
              :error

            data ->
              {:ok, data}
          end

        _ ->
          Logger.debug("Authorization header is not set")
          :error
      end

    case data do
      :error ->
        conn
        |> send_resp(401, "Bad authorization")
        |> halt()

      {:ok, data} ->
        assign(conn, :auth, data)
    end
  end
end
