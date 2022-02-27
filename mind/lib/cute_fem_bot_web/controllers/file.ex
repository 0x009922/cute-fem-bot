defmodule CuteFemBotWeb.Controllers.File do
  use CuteFemBotWeb, :controller

  def show(conn, %{"file_id" => id}) do
    {content_type, binary} = CuteFemBotWeb.Bridge.get_file(id)

    conn
    |> put_resp_content_type(content_type)
    |> send_resp(200, binary)
  end
end
