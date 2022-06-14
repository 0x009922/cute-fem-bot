defmodule CuteFemBot.Core.Pagination.Resolved do
  @moduledoc """
  Pagination data with info about page, its size and total items count
  """

  use TypedStruct

  @derive {Jason.Encoder, []}
  typedstruct enforce: true do
    field(:page, pos_integer())
    field(:page_size, pos_integer())
    field(:total, non_neg_integer())
  end

  def from_params(%CuteFemBot.Core.Pagination.Params{} = params, total)
      when is_integer(total) and total >= 0 do
    %__MODULE__{
      page: params.page,
      page_size: params.page_size,
      total: total
    }
  end
end
