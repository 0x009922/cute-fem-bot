defmodule CuteFemBotWeb.Bridge.IndexSuggestionsParams do
  use TypedStruct
  alias Ecto.Changeset
  alias CuteFemBot.Core.Pagination.Params, as: PaginationParams
  alias __MODULE__, as: Self

  typedstruct do
    field(:published, bool() | :whatever, default: :whatever)
    field(:decision, :sfw | :nsfw | nil | :whatever, default: :whatever)
    field(:pagination, PaginationParams.t(), enforce: true)
  end

  @changeset_types %{
    published: :boolean,
    decision: :string
  }

  def from_raw_query(query) do
    with {:ok, pagination} <- PaginationParams.from_raw_query(query, 10) do
      changeset =
        {%Self{pagination: pagination}, @changeset_types}
        |> Changeset.cast(query, Map.keys(@changeset_types))
        |> Changeset.validate_inclusion(:decision, ["sfw", "nsfw", "none", "whatever"])
        |> Changeset.update_change(:decision, fn x ->
          case x do
            "none" -> nil
            "whatever" -> :whatever
            "sfw" -> :sfw
            "nsfw" -> :nsfw
            _ -> x
          end
        end)

      if changeset.valid? do
        {:ok, Changeset.apply_changes(changeset)}
      else
        {:error, changeset}
      end
    end
  end

  def apply_to_query(%Ecto.Query{} = query, %Self{} = self) do
    query
    |> PaginationParams.apply_to_ecto_query(self.pagination)
    |> query_apply_decision(self)
    |> query_apply_published(self)
  end

  defp query_apply_decision(query, %Self{decision: :whatever}), do: query

  defp query_apply_decision(query, %Self{decision: decision}) do
    import Ecto.Query

    case decision do
      nil ->
        from(s in query, where: is_nil(s.decision))

      x ->
        decision = Atom.to_string(x)
        from(s in query, where: s.decision == ^decision)
    end
  end

  defp query_apply_published(query, %Self{published: :whatever}), do: query

  defp query_apply_published(query, %Self{published: value}) do
    import Ecto.Query

    from(s in query, where: s.published == ^value)
  end
end
