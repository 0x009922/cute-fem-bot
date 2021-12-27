defmodule ContextFall do
  @moduledoc """
  Generic pipeline
  """

  def handle(mod, ctx) do
    branch = get_module_main(mod)

    state = %{
      ctx: ctx,
      path: []
    }

    case walk(branch, state) do
      {:done, state} -> {:ok, state}
      {:dead_end, state} -> {:error, :dead_end, state}
    end
  end

  defp expose_state(state) do
    Map.to_list(state)
    |> Stream.filter(fn {key, _} -> key != :mod end)
    |> Enum.into(%{})
  end

  defp get_module_main(mod) do
    apply(mod, :main, []) |> Enum.map(fn fun -> {mod, fun} end)
  end

  defp walk([], state) do
    {:dead_end, state}
  end

  defp walk([branch | tail], state) when is_list(branch) do
    case walk(branch, state) do
      {:dead_end, state} -> walk(tail, state)
      x -> x
    end
  end

  defp walk([handler | handlers_tail], %{ctx: ctx} = state) do
    state = update_path(state, handler)

    result = with {mod, fun} <- handler, do: apply(mod, fun, [ctx])

    case result do
      :halt ->
        {:done, state}

      {:halt, ctx} ->
        {:done, update_ctx(state, ctx)}

      # just go next
      {:cont, ctx} ->
        walk(tail, update_ctx(state, ctx))

      {:insert_branch, branch, ctx} ->
        walk([branch | handlers_tail], update_ctx(state, ctx))

      {:insert_mod, module, ctx} ->
        state = update_ctx(state, ctx)
        branch = get_module_main(module)
        walk([branch | handlers_tail], state)
    end
  end

  defp update_ctx(state, ctx), do: %{state | ctx: ctx}

  defp update_path(%{path: path} = state, new_step), do: %{state | path: [new_step | path]}
end
