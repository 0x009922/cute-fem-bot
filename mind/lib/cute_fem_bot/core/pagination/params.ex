defmodule CuteFemBot.Core.Pagination.Params do
  alias CuteFemBot.Core.Pagination.Params, as: Self
  alias Ecto.Changeset

  use TypedStruct

  @derive {Jason.Encoder, []}
  typedstruct do
    field(:page, pos_integer(), default: 1)
    field(:page_size, pos_integer(), enforce: true)
  end

  @changeset_types %{
    page: :integer,
    page_size: :integer
  }

  def new(page, page_size) do
    %Self{
      page: page,
      page_size: page_size
    }
  end

  def from_raw_query(query_map, default_page_size) do
    changeset =
      {%Self{page_size: default_page_size}, @changeset_types}
      |> Changeset.cast(query_map, Map.keys(@changeset_types))
      |> Changeset.validate_number(:page, greater_than: 0)
      |> Changeset.validate_number(:page_size, greater_than: 0)

    if changeset.valid? do
      {:ok, Changeset.apply_changes(changeset)}
    else
      {:error, changeset}
    end
  end

  def apply_to_ecto_query(query, %Self{} = self) do
    import Ecto.Query

    offset = (self.page - 1) * self.page_size
    from(x in query, limit: ^self.page_size, offset: ^offset)
  end
end
