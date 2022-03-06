defmodule CuteFemBotWeb.Controllers.File do
  use CuteFemBotWeb, :controller

  def show(conn, %{"file_id" => id}) do
    {content_type, binary} = CuteFemBotWeb.Bridge.get_file(id)

    conn
    |> put_resp_content_type(content_type)
    |> put_resp_header("cache-control", "max-age=31536000, immutable")
    |> send_resp(200, binary)
  end
end
