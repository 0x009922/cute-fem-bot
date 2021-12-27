defmodule CuteFemBot.Logic.Handler do
  @moduledoc """
  Main handler for incoming telegram updates
  """

  # impl of Telegram Handler

  @behaviour CuteFemBot.Telegram.Handler

  @impl true
  def handle_update(update) do
    CuteFemBot.Logic.Handler |> GenServer.cast({:handle_update, update})
  end

  # impl GenServer

  use GenServer

  @impl true
  def init(opts) do
    persistent = Keyword.fetch!(opts, :persistent)

    {:ok, %{persistent: persistent}}
  end

  @impl true
  def handle_cast({:handle_update, update}, state) do
    # now actually handling update

    {:no_reply, state}
  end

  defp apply_middleware_module(mod, update, init_ctx) do
    %{main: branch} = apply(mod, :schema, [])

    middleware_walk(branch, %{ctx: init_ctx, update: update, mod: mod})
  end

  defp middleware_walk([], _) do
    :end_is_reached
  end

  defp middleware_walk([sub_branch | tail], ctx) when is_list(sub_branch) do
    case middleware_walk(sub_branch, ctx) do
      :end_is_reached -> middleware_walk(tail, ctx)
      x -> x
    end
  end

  defp middleware_walk(
         [middleware | branch],
         %{ctx: ctx, update: upd, mod: mod} = state
       ) do
    result = apply(mod, middleware, [upd, ctx])

    case result do
      :halt ->
        # TODO halting
        {:halt, middleware}

      :next ->
        # just go next
        middleware_walk(branch, state)

      {:next, opts} ->
        ctx = Keyword.get(opts, :ctx, ctx)
        sub_branch = Keyword.get(opts, :sub_branch, nil)

        branch =
          case sub_branch do
            nil -> branch
            _ -> [sub_branch | branch]
          end

        middleware_walk(branch, %{state | ctx: ctx})

      _ ->
        {:bad_middleware_result, middleware, result}
    end
  end
end
