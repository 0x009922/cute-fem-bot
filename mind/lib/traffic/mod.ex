defmodule Traffic do
  alias Traffic.Context

  @type ctx() :: Context.t()
  @type point() :: module() | fun()
  @type run_error() :: :not_halted | {:ctx_lost, ctx(), any()}

  @spec run(ctx(), [point()]) :: {:ok, ctx()} | {:error, run_error()}
  def run(ctx, points) do
    ctx = move_on(ctx, points)

    case ctx do
      %Context{halted: false} ->
        {:error, :not_halted}

      %Context{} = ctx ->
        {:ok, ctx}

      {:ctx_lost, %Context{}, _bad_return} = err ->
        {:error, err}

      {:raise, _err, _trace, _ctx} = err ->
        {:error, err}
    end
  end

  @spec move_on(ctx(), [point()]) :: ctx()
  def move_on(ctx, points)

  def move_on(%Context{halted: true} = ctx, _), do: ctx

  def move_on(ctx, [point | other_points]) do
    ctx = push_trace(ctx, point)

    try do
      case handle_point(ctx, point) do
        %Context{} = ctx -> move_on(ctx, other_points)
        bad_stuff -> {:ctx_lost, ctx, bad_stuff}
      end
    rescue
      any_error -> {:raise, any_error, __STACKTRACE__, ctx}
    end
  end

  def move_on(ctx, []), do: ctx

  defp handle_point(ctx, point) when is_function(point), do: point.(ctx)
  defp handle_point(ctx, point) when is_atom(point), do: apply(point, :handle, [ctx])

  defp push_trace(%Context{trace: trace} = ctx, point), do: %Context{ctx | trace: [point | trace]}
end
