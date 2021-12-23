defmodule CuteFemBot.Tg.Types.User do
  use TypedStruct

  typedstruct do
    field(:id, integer(), enforce: true)
    field(:is_bot, bool(), enforce: true)
    field(:first_name, String.t(), enforce: true)
    field(:last_name, String.t())
    field(:username, String.t())
    field(:language_code, String.t())
  end

  def parse(%{"id" => id, "is_bot" => bot, "first_name" => first_name} = raw) do
    %__MODULE__{
      id: id,
      is_bot: bot,
      first_name: first_name,
      last_name: Map.get(raw, "text"),
      username: Map.get(raw, "entities"),
      language_code: Map.get(raw, "document")
    }
  end
end
