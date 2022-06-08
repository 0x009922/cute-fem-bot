defmodule Traffic do
  alias Traffic.Context

  @type ctx() :: Traffic.Context.t()
  @type point() :: module() | fun()
  @type run_error() :: :not_halted

  @spec run(ctx(), [point()]) :: {:ok, ctx()} | {:error, run_error()}
  def run(ctx, points) do
    ctx = move_on(ctx, points)

    case ctx do
      %Context{halted: false} -> {:error, :not_halted}
      ctx -> {:ok, ctx}
    end
  end

  @spec move_on(ctx(), [point()]) :: ctx()
  def move_on(ctx, points)

  def move_on(%Context{halted: true} = ctx, _), do: ctx

  def move_on(ctx, [point | other_points]) do
    treat_point(ctx, point)
    |> move_on(other_points)
  end

  def move_on(ctx, []), do: ctx

  defp treat_point(ctx, point) when is_function(point), do: point.(ctx)
  defp treat_point(ctx, point) when is_atom(point), do: apply(point, :treat, [ctx])
end
