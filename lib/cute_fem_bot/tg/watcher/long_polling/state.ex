defmodule CuteFemBot.Tg.Watcher.LongPolling.State do
  use TypedStruct

  typedstruct do
    field(:greatest_known_update_id, non_neg_integer(), default: nil)
  end
end
