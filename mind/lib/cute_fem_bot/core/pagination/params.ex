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

  # defp get_query_page(%{"page" => p}) do
  #   case str_to_int_and_greater_or_equal_than_1(p) do
  #     {:error, str} -> {:error, "invalid page: #{str}"}
  #     {:ok, _} = ok -> ok
  #   end
  # end

  # defp get_query_page(_), do: {:ok, 1}

  # defp get_query_page_size(%{"page_size" => x}, _) do
  #   case str_to_int_and_greater_or_equal_than_1(x) do
  #     {:error, str} -> {:error, "invalid page size: #{str}"}
  #     {:ok, _} = ok -> ok
  #   end
  # end

  # defp get_query_page_size(_, default_val), do: {:ok, default_val}

  # defp str_to_int_and_greater_or_equal_than_1(str_val) do
  #   case Integer.parse(str_val) do
  #     :error ->
  #       {:error, "bad integer: #{str_val}"}

  #     {num, _decimal} ->
  #       if num >= 1 do
  #         {:ok, num}
  #       else
  #         {:error, "value is less than 1: #{num}"}
  #       end
  #   end
  # end
end
