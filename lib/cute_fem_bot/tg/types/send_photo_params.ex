defmodule CuteFemBot.Tg.Types.SendPhotoParams do
  use TypedStruct

  typedstruct do
    field(:chat_id, integer(), enforce: true)
    field(:file_id, String.t(), enforce: true)
  end

  alias __MODULE__, as: Self

  def to_json(%Self{chat_id: chat_id, file_id: file_id}) do
    %{"chat_id" => chat_id, "photo" => file_id}
  end
end
