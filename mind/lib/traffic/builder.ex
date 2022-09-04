defmodule Traffic.Builder do
  @builder_points_acc_name :traffic_builder_points
  @handler_arity 1

  defmacro __using__(opts \\ []) do
    quote location: :keep do
      @behaviour Traffic.Point

      @builder_opts unquote(opts)

      def handle(ctx) do
        traffic_builder_handle(ctx)
      end

      import Traffic.Context
      import Traffic.Builder, only: [over: 1, over_if: 2]

      Module.register_attribute(__MODULE__, unquote(@builder_points_acc_name), accumulate: true)
      @before_compile Traffic.Builder
    end
  end

  defmacro __before_compile__(env) do
    opts = Module.get_attribute(env.module, :builder_opts)

    debug = Keyword.get(opts, :debug, false)

    points =
      Module.get_attribute(env.module, @builder_points_acc_name)
      |> Stream.map(fn
        {:point, point} ->
          expand_point(env, point)

        {:point_if, guard, point} ->
          point_expanded = expand_point(env, point)

          quote location: :keep do
            fn %Traffic.Context{} = ctx ->
              if unquote(guard).(ctx) do
                Traffic.move_on(ctx, [unquote(point_expanded)])
              else
                ctx
              end
            end
          end
      end)
      |> Enum.reverse()

    debug_quote =
      if debug do
        quote location: :keep do
          IO.inspect(unquote(points), label: "Debugging #{unquote(env.module)} points")
        end
      else
        quote do: nil
      end

    quote location: :keep do
      unquote(debug_quote)

      defp traffic_builder_handle(ctx) do
        Traffic.move_on(ctx, unquote(points))
      end
    end
  end

  defmacro over(point) do
    quote location: :keep do
      Module.put_attribute(
        unquote(__CALLER__.module),
        unquote(@builder_points_acc_name),
        {:point, unquote(Macro.escape(point))}
      )
    end
  end

  defmacro over_if(guard, point) do
    quote location: :keep do
      Module.put_attribute(
        unquote(__CALLER__.module),
        unquote(@builder_points_acc_name),
        {:point_if, unquote(Macro.escape(guard)), unquote(Macro.escape(point))}
      )
    end
  end

  defp is_module?(x), do: match?(~c"Elixir." ++ _, Atom.to_charlist(x))

  defp is_module_public_handler?(mod, fun_name),
    do: Module.defines?(mod, {fun_name, @handler_arity}, :def)

  defp expand_point(env, point) when is_atom(point) do
    cond do
      is_module?(point) ->
        point

      is_module_public_handler?(env.module, point) ->
        quote location: :keep do
          Function.capture(unquote(env.module), unquote(point), unquote(@handler_arity))
        end

      true ->
        raise "expected #{inspect(point)} to be a module or a public function of #{env.module} module"
    end
  end

  defp expand_point(_, x), do: x
end
