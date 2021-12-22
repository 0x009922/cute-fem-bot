defmodule CuteFemBot.Tg.Types.Message do
  use TypedStruct

  typedstruct do
    field(:chat, any(), enforce: true)
    field(:from, any())
    field(:photo, any())
    field(:text, any())
    field(:entities, any())
  end

  def parse(%{} = raw) do
    %__MODULE__{
      chat: Map.fetch!(raw, "chat"),
      from: Map.get(raw, "from"),
      photo: Map.get(raw, "photo"),
      text: Map.get(raw, "text"),
      entities: Map.get(raw, "entities")
    }
  end
end
