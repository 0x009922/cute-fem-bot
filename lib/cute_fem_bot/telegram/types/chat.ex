defmodule CuteFemBot.Tg.Types.Chat do
  use TypedStruct

  typedstruct do
    field(:id, non_neg_integer(), enforce: true)
  end

  def parse(%{"id" => id}) do
    %__MODULE__{id: id}
  end
end
