defmodule CtxHandler do
  alias __MODULE__.State

  def handle(mod, ctx) do
    branch = get_module_main(mod)

    state = %State{
      ctx: ctx
    }

    case walk(branch, state) do
      {:done, %State{} = state} ->
        {:ok, state |> expose_state}

      {:dead_end, %State{} = state} ->
        {:error, :dead_end, state |> expose_state}

      {:bad_handler_answer, answer, %State{} = state} ->
        {:error, :bad_answer, answer, state |> expose_state}

      {:raised, err, trace, state} ->
        {:error, :raised, err, trace, state |> expose_state}
    end
  end

  defp expose_state(%State{} = state) do
    state
    |> reverse_path
  end

  defp reverse_path(%State{path: path} = state) do
    %State{state | path: Enum.reverse(path)}
  end

  defp get_module_main(mod) do
    apply(mod, :main, [])
    |> Enum.map(fn entry ->
      case entry do
        {_, _} = full -> full
        fun -> {mod, fun}
      end
    end)
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

  defp walk([handler | handlers_tail], %State{ctx: ctx} = state) do
    state = update_path(state, handler)

    result =
      with {mod, fun} <- handler do
        try do
          apply(mod, fun, [ctx])
        rescue
          err ->
            {:raised, err, __STACKTRACE__}
        end
      end

    case result do
      {:raised, err, trace} ->
        {:raised, err, trace, state}

      :halt ->
        {:done, state}

      {:halt, ctx} ->
        {:done, update_ctx(state, ctx)}

      :cont ->
        walk(handlers_tail, state)

      {:cont, ctx} ->
        walk(handlers_tail, update_ctx(state, ctx))

      {:cont, :sub_branch, branch, ctx} ->
        {mod, _} = handler
        branch = Enum.map(branch, fn fun -> {mod, fun} end)
        walk([branch | handlers_tail], update_ctx(state, ctx))

      {:cont, :sub_mod, module, ctx} ->
        state = update_ctx(state, ctx)
        branch = get_module_main(module)
        walk([branch | handlers_tail], state)

      bad_answer ->
        {:bad_handler_answer, bad_answer, state}
    end
  end

  defp update_ctx(state, ctx), do: %State{state | ctx: ctx}

  defp update_path(%State{path: path} = state, new_step) do
    %State{state | path: [new_step | path]}
  end
end
