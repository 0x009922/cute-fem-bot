defmodule CuteFemBot.Tg.Types.Update do
  use TypedStruct

  alias CuteFemBot.Tg.Types.Message

  typedstruct do
    field(:update_id, non_neg_integer(), enforce: true)
    field(:value, {:message, Message.t()} | {:callback_query, any()} | :unknown)
  end

  def parse(%{} = raw) do
    %__MODULE__{
      update_id: Map.fetch!(raw, "update_id"),
      value:
        case raw do
          %{"message" => msg} -> {:message, Message.parse(msg)}
          %{"callback_query" => query} -> {:callback_query, query}
          _ -> :unknown
        end
    }
  end
end
