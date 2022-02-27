defmodule CuteFemBotWeb.Controllers.Suggestions do
  use CuteFemBotWeb, :controller

  def index(%Plug.Conn{} = conn, _) do
    data =
      CuteFemBotWeb.Bridge.index_suggestions(
        only_with_decision:
          case Map.get(conn.query_params, "queue", false) do
            "true" -> true
            _ -> false
          end
      )

    json(conn, data)
  end

  def update(%Plug.Conn{body_params: params} = conn, %{"file_id" => id}) do
    case CuteFemBotWeb.Bridge.update_suggestion(id, params) do
      :ok -> send_resp(conn, 200, "Suggestion is updated")
      {:error, err} -> send_resp(conn, 400, "Error occured: #{inspect(err)}")
    end

    # IO.inspect({id, conn.body_params}, label: "update suggestion")
    # send_resp(conn, 400, "")
  end
end
