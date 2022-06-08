defmodule Traffic.Point do
  @callback treat(Traffic.Context.t()) :: Traffic.Context.t()
end
