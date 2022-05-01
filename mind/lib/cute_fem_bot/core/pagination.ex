defmodule CuteFemBot.Core.Pagination do
  use TypedStruct

  typedstruct do
    field(:page, pos_integer(), enforce: true)
    field(:page_size, pos_integer(), enforce: true)
    field(:items_total, pos_integer(), enforce: true)
  end

  def new(page, page_size, items_total) do
    %__MODULE__{
      page: page,
      page_size: page_size,
      items_total: items_total
    }
  end
end
