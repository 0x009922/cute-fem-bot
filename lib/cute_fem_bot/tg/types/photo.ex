defmodule CuteFemBot.Tg.Types.Photo do
  use TypedStruct

  typedstruct do
    field(:file_id, String.t(), enforce: true)
  end

  def parse(%{"file_id" => id}) do
    %__MODULE__{file_id: id}
  end
end
