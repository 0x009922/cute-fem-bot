defmodule CtxHandler.State do
  use TypedStruct

  typedstruct do
    field(:ctx, any(), enforce: true)
    field(:path, list({atom(), atom()}), default: [])
  end
end
