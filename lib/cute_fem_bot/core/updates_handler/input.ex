defmodule CuteFemBot.Core.UpdatesHandler.Input do
  use TypedStruct

  typedstruct do
    field(:moderation_chat_id, non_neg_integer(), enforce: true)
    field(:banned_users, list(integer()), enforce: true)
    field(:updates, nonempty_list(Types.Update.t()), enforce: true)
  end
end
