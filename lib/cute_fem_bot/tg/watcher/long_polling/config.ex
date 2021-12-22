defmodule CuteFemBot.Tg.Watcher.LongPolling.Config do
  use TypedStruct

  typedstruct do
    field(:interval, non_neg_integer(), enforce: true)
  end
end
