defmodule CuteFemBotWeb.Controllers.Suggestions do
  use CuteFemBotWeb, :controller

  def index(%Plug.Conn{query_params: query} = conn, _) do
    params_result = CuteFemBotWeb.Bridge.IndexSuggestionsParams.from_raw_query(query)

    case params_result do
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:bad_request)
        |> json(CuteFemBot.Util.format_changeset_errors(changeset))

      {:ok, params} ->
        data = CuteFemBotWeb.Bridge.index_suggestions(params)

        conn
        |> json(data)
    end
  end

  def update(%Plug.Conn{body_params: params} = conn, %{"file_id" => id}) do
    case CuteFemBotWeb.Bridge.update_suggestion(id, params) do
      :ok ->
        conn
        |> put_status(:ok)
        |> text("Suggestion is updated")

      {:error, err} ->
        conn
        |> put_status(:bad_request)
        |> text("Error occured: #{inspect(err)}")
    end
  end
end
