defmodule CuteFemBot.Core.UpdatesHandler.Output do
  use TypedStruct

  typedstruct do
    field(:actions, list(), enforce: true)
  end
end
