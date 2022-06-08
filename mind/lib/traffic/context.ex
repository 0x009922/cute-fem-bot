defmodule Traffic.Context do
  alias Traffic.Context, as: Self

  use TypedStruct

  typedstruct enforce: true do
    field(:halted, bool(), default: false)
    field(:halt_payload, any(), default: nil)
    field(:payload, any())
  end

  def with_payload(payload) do
    %Self{payload: payload}
  end

  def halt(%Self{} = ctx, reason \\ nil) do
    %Self{ctx | halted: true, halt_payload: reason}
  end

  def set_payload(%Self{} = ctx, payload) do
    %Self{ctx | payload: payload}
  end
end
