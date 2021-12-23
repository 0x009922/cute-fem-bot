defmodule CuteFemBot.Tg.Types.Message do
  use TypedStruct

  alias CuteFemBot.Tg.Types

  typedstruct do
    field(:chat, Types.Chat.t(), enforce: true)
    field(:from, Types.User.t())
    field(:photo, list(Types.Photo.t()))
    field(:document, any())
    field(:text, any())
    field(:entities, any())
  end

  def parse(%{"chat" => chat} = raw) do
    %__MODULE__{
      chat: Types.Chat.parse(chat),
      from:
        case raw do
          %{"from" => from} when not is_nil(from) -> Types.User.parse(from)
          _ -> nil
        end,
      photo:
        case raw do
          %{"photo" => photo_size_list} when is_list(photo_size_list) ->
            Enum.map(photo_size_list, &Types.Photo.parse/1)

          _ ->
            nil
        end,
      text: Map.get(raw, "text"),
      entities: Map.get(raw, "entities"),
      document: Map.get(raw, "document")
    }
  end
end
