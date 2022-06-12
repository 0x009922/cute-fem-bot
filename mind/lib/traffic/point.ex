defmodule Traffic.Point do
  @callback handle(Traffic.Context.t()) :: Traffic.Context.t()
end
