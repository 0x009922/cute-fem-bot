defmodule CuteFemBot.Tg.Api.Config do
  @moduledoc """
  Special config for Api module
  """

  use TypedStruct

  typedstruct do
    field(:token, String.t(), enforce: true)
    field(:finch, any(), enforce: true)
  end
end
