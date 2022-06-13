defmodule CuteFemBot.Logic.Handler.ContextUtils do
  alias Traffic.Context
  alias CuteFemBot.Logic.Handler.Context, as: HandlerContext

  @doc """
  Utility used to conditionally run middleware when some user command (or commands) is occured in the message.

  """
  defmacro over_if_command(cmd, point) when is_binary(cmd) do
    over_commands_guard([cmd], point)
  end

  defmacro over_if_command(cmds, point) when is_list(cmds) do
    over_commands_guard(cmds, point)
  end

  defp over_commands_guard(cmds, point) when is_list(cmds) do
    quote location: :keep do
      over_if(
        fn %Context{} = ctx ->
          Enum.any?(unquote(cmds), fn x -> HandlerContext.has_command?(ctx, x) end)
        end,
        unquote(point)
      )
    end
  end
end
