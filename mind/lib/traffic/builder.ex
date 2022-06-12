defmodule Traffic.Builder do
  @builder_points_acc_name :traffic_builder_points
  @handler_arity 1

  defmacro __using__(_opts) do
    quote do
      @behaviour Traffic.Point

      def handle(ctx) do
        traffic_builder_handle(ctx)
      end

      import Traffic.Context
      import Traffic.Builder, only: [over: 1]

      Module.register_attribute(__MODULE__, unquote(@builder_points_acc_name), accumulate: true)
      @before_compile Traffic.Builder
    end
  end

  defmacro __before_compile__(env) do
    points =
      Module.get_attribute(env.module, @builder_points_acc_name)
      |> Stream.map(fn
        x when is_atom(x) ->
          cond do
            is_module?(x) ->
              x

            is_module_public_handler?(env.module, x) ->
              quote do
                Function.capture(unquote(env.module), unquote(x), unquote(@handler_arity))
              end

            true ->
              raise "expected #{inspect(x)} to be a module or a public function of #{env.module} module"
          end

        x ->
          x
      end)
      |> Enum.reverse()

    quote location: :keep do
      defp traffic_builder_handle(ctx) do
        Traffic.move_on(ctx, unquote(points))
      end
    end
  end

  defmacro over(point) do
    quote do
      Module.put_attribute(
        unquote(__CALLER__.module),
        unquote(@builder_points_acc_name),
        unquote(Macro.escape(point))
      )
    end
  end

  defp is_module?(x), do: match?(~c"Elixir." ++ _, Atom.to_charlist(x))

  defp is_module_public_handler?(mod, fun_name),
    do: Module.defines?(mod, {fun_name, @handler_arity}, :def)
end
