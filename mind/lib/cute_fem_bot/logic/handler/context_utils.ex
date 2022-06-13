defmodule CuteFemBot.Logic.Handler.ContextUtils do
  alias Traffic.Context
  alias CuteFemBot.Logic.Handler.Context, as: HandlerContext

  @doc """
  Utility used to conditionally run middleware when some user command (or commands) is occured in the message.

  Middleware type is that supported by `Traffic.move_on()` function, i.e. a function or a module.
  """
  defmacro over_if_command(cmd, fun) when is_binary(cmd) do
    over_commands_guard([cmd], fun)
  end

  defmacro over_if_command(cmds, fun) when is_list(cmds) do
    over_commands_guard(cmds, fun)
  end

  defp over_commands_guard(cmds, fun) when is_list(cmds) do
    quote location: :keep do
      over(fn %Context{} = ctx ->
        if Enum.any?(unquote(cmds), fn x -> HandlerContext.has_command?(ctx, x) end) do
          Traffic.move_on(ctx, [unquote(fun)])
        else
          ctx
        end
      end)
    end
  end
end
