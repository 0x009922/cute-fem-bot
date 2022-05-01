defmodule CuteFemBotWeb.Controllers.File do
  use CuteFemBotWeb, :controller

  def show(conn, %{"file_id" => id}) do
    case CuteFemBotWeb.Bridge.get_file(id) do
      {:ok, content_type, binary} ->
        conn
        |> put_resp_content_type(content_type)
        |> put_resp_header("cache-control", "max-age=31536000, immutable")
        |> send_resp(200, binary)

      {:error, :unavailable} ->
        conn
        |> put_resp_header("cache-control", "max-age=31536000, immutable")
        |> send_resp(204, "")

      {:error, _} ->
        conn
        |> put_resp_header("cache-control", "max-age=1000")
        |> send_resp(404, "Something went wrong while tried to fetch file :<")
    end
  end
end
