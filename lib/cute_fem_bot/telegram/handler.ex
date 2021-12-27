defmodule CuteFemBot.Telegram.Handler do
  @moduledoc """
  Behavior for handler module
  """

  @callback handle_update(update: any()) :: any()
end
