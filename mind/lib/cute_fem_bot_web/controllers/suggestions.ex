defmodule CuteFemBotWeb.Controllers.Suggestions do
  use CuteFemBotWeb, :controller

  def index(%Plug.Conn{query_params: query} = conn, _) do
    params_result = CuteFemBot.Persistence.IndexSuggestionsParams.from_raw_query(query)

    case params_result do
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:bad_request)
        |> json(CuteFemBot.Util.format_changeset_errors(changeset))

      {:ok, params} ->
        data = CuteFemBot.Persistence.index_suggestions(params)

        conn
        |> json(data)
    end
  end

  def make_decision(%Plug.Conn{body_params: params, assigns: %{auth: auth}} = conn, %{
        "file_id" => id
      }) do
    with {:ok, decision} <- parse_decision(params),
         user_id = extract_user_id(auth),
         :ok <- CuteFemBotWeb.Bridge.make_suggestion_decision(id, decision, user_id) do
      conn
      |> put_status(:ok)
      |> text("Decision is made")
    else
      {:error, err} ->
        conn
        |> put_status(:bad_request)
        |> text("Error occured: #{inspect(err)}")
    end
  end

  @spec extract_user_id(CuteFemBotWeb.Auth.auth_data()) :: pos_integer()
  defp extract_user_id({user_id, _}), do: user_id

  @make_decision_params_types %{
    decision: {:parameterized, Ecto.Enum, Ecto.Enum.init(values: ~w(sfw nsfw reject)a)}
  }

  # public for testing
  def parse_decision(params) do
    changeset =
      {%{}, @make_decision_params_types}
      |> Ecto.Changeset.cast(params, [:decision])
      |> Ecto.Changeset.validate_required(:decision)

    if changeset.valid? do
      {:ok, Ecto.Changeset.apply_changes(changeset) |> Map.get(:decision)}
    else
      {:error, CuteFemBot.Util.format_changeset_errors(changeset)}
    end
  end
end
