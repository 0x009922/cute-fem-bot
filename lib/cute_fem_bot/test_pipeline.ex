defmodule TestPipeline do
  # main([
  #   :first,
  #   :second
  # ])

  def main() do
    [
      :first,
      :second
    ]
  end

  def first(ctx, _opts) do
    {:next, ctx}
    # next(ctx)
    # {:next, ctx}
  end

  def second(ctx, _opts) do
    {:next, :sub_chain, [:third], ctx}
    # next(:pipe, :third, ctx)
    # {:next_branch, [:third], ctx}
  end

  def third(_, _) do
    if 1 > 2 do
      :halt
    else
      # {:next, :sub_module, SecondPipeline, ctx}
    end
  end
end
