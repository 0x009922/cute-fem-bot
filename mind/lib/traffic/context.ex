defmodule Traffic.Context do
  alias Traffic.Context, as: Self

  use TypedStruct

  typedstruct enforce: true do
    field(:halted, bool(), default: false)
    field(:halt_reason, any(), default: nil)
    field(:trace, [any()], default: [])
    field(:assigns, map(), default: %{})
  end

  def new do
    %Self{}
  end

  def halt(%Self{} = self, reason \\ nil) do
    %Self{self | halted: true, halt_reason: reason}
  end

  def assign(%Self{} = self, key, value) do
    %Self{self | assigns: Map.put(self.assigns, key, value)}
  end
end
