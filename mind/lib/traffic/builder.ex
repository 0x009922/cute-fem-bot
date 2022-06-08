defmodule Traffic.Builder do
  defmacro __using__(opts) do
    quote do
      @behaviour Traffic.Point

      def treat(ctx) do
        traffic_builder_call(ctx)
      end

      import Traffic.Context
      import Traffic.Builder, only: [over: 1]

      Module.register_attribute(__MODULE__, :traffic_points, accumulate: true)
      @before_compile Traffic.Builder
    end
  end

  defmacro __before_compile__(env) do
    points = Module.get_attribute(env.module, :traffic_points)

    caller_module = __CALLER__.module

    points_transformed =
      points
      |> Stream.map(fn
        x when is_function(x) ->
          x

        x when is_atom(x) ->
          cond do
            is_module?(x) ->
              x

            Module.defines?(caller_module, {x, 1}, :def) ->
              quote do
                Function.capture(unquote(caller_module), unquote(x), 1)
              end

            true ->
              raise "module #{inspect(caller_module)} should export #{inspect(x)}"
          end
      end)
      |> Enum.reverse()

    quote do
      defp traffic_builder_call(ctx) do
        Traffic.move_on(ctx, unquote(points_transformed))
      end
    end
  end

  defmacro over(point) do
    quote do
      @traffic_points unquote(point)
    end
  end

  defp is_module?(x), do: match?(~c"Elixir." ++ _, Atom.to_charlist(x))
end
