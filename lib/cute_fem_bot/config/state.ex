defmodule CuteFemBot.Config.State do
  def init(%CuteFemBot.Config{} = cfg) do
    ref = :ets.new(CuteFemBot.Config.State, [:set, :protected])
    :ets.insert(ref, {:cfg, cfg})
    {:ok, ref}
  end

  @spec lookup!(atom | :ets.tid()) :: CuteFemBot.Config.t()
  def lookup!(ref) do
    case :ets.lookup(ref, :cfg) do
      [{:cfg, %CuteFemBot.Config{} = cfg}] -> cfg
    end
  end
end
