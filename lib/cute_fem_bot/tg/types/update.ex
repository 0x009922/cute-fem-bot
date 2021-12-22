defmodule CuteFemBot.Tg.Types.Update do
  use TypedStruct

  alias CuteFemBot.Tg.Types.Message

  typedstruct do
    field(:update_id, non_neg_integer(), enforce: true)
    field(:message, Message.t())
  end

  def parse(%{} = raw) do
    %__MODULE__{
      update_id: Map.fetch!(raw, "update_id"),
      message:
        case Map.get(raw, "message") do
          nil -> nil
          x -> Message.parse(x)
        end
    }
  end
end
