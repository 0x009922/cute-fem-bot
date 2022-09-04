defmodule Traffic do
  alias Traffic.Context

  @type ctx() :: Context.t()
  @type point() :: module() | fun()
  @type run_error() ::
          {:not_halted, ctx()} | {:ctx_lost, ctx(), any()} | {:raised, any(), any(), ctx()}

  @spec run(ctx(), [point()]) :: {:ok, ctx()} | {:error, run_error()}
  def run(ctx, points) do
    try do
      ctx = move_on(ctx, points)

      case ctx do
        %Context{halted: false} -> {:error, {:not_halted, ctx}}
        _ -> {:ok, ctx}
      end
    catch
      {:traffic_context_lost, ctx, bad_value} -> {:error, {:ctx_lost, ctx, bad_value}}
      {:traffic_point_raised, err, stacktrace, ctx} -> {:error, {:raised, err, stacktrace, ctx}}
    end
  end

  @doc """
  Works properly only inside of `run()`
  """
  @spec move_on(ctx(), [point()]) :: ctx()
  def move_on(ctx, points)

  def move_on(%Context{halted: true} = ctx, _), do: ctx

  def move_on(%Context{} = ctx, [point | other_points]) do
    ctx = push_trace(ctx, point)

    result =
      try do
        {:ok, handle_point(ctx, point)}
      rescue
        any_error -> {:error, any_error, __STACKTRACE__, ctx}
      end

    case result do
      {:ok, value} ->
        case value do
          %Context{} = ctx ->
            move_on(ctx, other_points)

          bad_stuff ->
            throw({:traffic_context_lost, ctx, bad_stuff})
        end

      {:error, err, stacktrace, ctx} ->
        throw({:traffic_point_raised, err, stacktrace, ctx})
    end
  end

  def move_on(%Context{} = ctx, []), do: ctx

  defp handle_point(ctx, point) when is_function(point), do: point.(ctx)
  defp handle_point(ctx, point) when is_atom(point), do: apply(point, :handle, [ctx])

  defp push_trace(%Context{trace: trace} = ctx, point), do: %Context{ctx | trace: [point | trace]}
end
