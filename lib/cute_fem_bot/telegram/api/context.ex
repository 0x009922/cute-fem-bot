defmodule CuteFemBot.Telegram.Api.Context do
  @moduledoc """
  Context for api calls
  """

  use TypedStruct

  typedstruct do
    field(:finch, any(), enforce: true)
    field(:config, any(), enforce: true)
  end
end
