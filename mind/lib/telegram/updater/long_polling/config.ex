defmodule Telegram.Updater.LongPolling.Config do
  use TypedStruct

  typedstruct do
    field(:interval, non_neg_integer() | fun(), enforce: true)
    field(:dispatcher, any, enforce: true)
    field(:api, any, enforce: true)
  end
end
