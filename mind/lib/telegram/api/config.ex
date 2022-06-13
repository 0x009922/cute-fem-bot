defmodule Telegram.Api.Config do
  @moduledoc """
  Context for api calls
  """

  use TypedStruct

  typedstruct do
    field(:finch, atom(), enforce: true)
    field(:token, String.t() | fun(), enforce: true)
  end
end
