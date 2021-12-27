defmodule CuteFemBot.Telegram.Api.Context do
  @moduledoc """
  Context for api calls
  """

  use TypedStruct

  typedstruct do
    field(:token, String.t(), enforce: true)
    field(:finch, any(), enforce: true)
  end
end
