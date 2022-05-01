defmodule CuteFemBot.Core.Pagination.Params do
  alias CuteFemBot.Core.Pagination.Params, as: Self

  use TypedStruct

  @derive {Jason.Encoder, []}
  typedstruct do
    field(:page, pos_integer(), enforce: true)
    field(:page_size, pos_integer(), enforce: true)
  end

  def new(page, page_size) do
    %__MODULE__{
      page: page,
      page_size: page_size
    }
  end

  def from_raw_query(query_map, default_page_size) do
    with {:ok, page} <- get_query_page(query_map),
         {:ok, page_size} <- get_query_page_size(query_map, default_page_size) do
      {:ok, new(page, page_size)}
    end
  end

  def apply_to_ecto_query(query, %Self{} = self) do
    import Ecto.Query

    offset = (self.page - 1) * self.page_size
    from(x in query, limit: ^self.page_size, offset: ^offset)
  end

  defp get_query_page(%{"page" => p}) do
    case str_to_int_and_greater_or_equal_than_1(p) do
      {:error, str} -> {:error, "invalid page: #{str}"}
      {:ok, _} = ok -> ok
    end
  end

  defp get_query_page(_), do: {:ok, 1}

  defp get_query_page_size(%{"page_size" => x}, _) do
    case str_to_int_and_greater_or_equal_than_1(x) do
      {:error, str} -> {:error, "invalid page size: #{str}"}
      {:ok, _} = ok -> ok
    end
  end

  defp get_query_page_size(_, default_val), do: {:ok, default_val}

  defp str_to_int_and_greater_or_equal_than_1(str_val) do
    case Integer.parse(str_val) do
      :error ->
        {:error, "bad integer: #{str_val}"}

      {num, _decimal} ->
        if num >= 1 do
          {:ok, num}
        else
          {:error, "value is less than 1: #{num}"}
        end
    end
  end
end
