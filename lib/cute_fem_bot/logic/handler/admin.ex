defmodule CuteFemBot.Logic.Handler.Admin do
  @moduledoc """
  Admin route - queue, schedule, unban
  """

  alias __MODULE__, as: Self
  alias Self.Shared
  alias Self.Queue
  alias Self.Schedule
  alias CuteFemBot.Telegram.Types.Message
  alias CuteFemBot.Persistence
  alias CuteFemBot.Logic.Handler.Ctx
  alias CuteFemBot.Logic

  require Logger

  def main() do
    [
      :fetch_chat_state,
      :extract_commands_from_message,
      :handle_unban_commands,
      :handle_commands,
      {Queue, :handle},
      {Schedule, :handle},
      :skip
    ]
  end

  def fetch_chat_state(ctx) do
    {:cont, Shared.fetch_chat_state(ctx)}
  end

  def extract_commands_from_message(ctx) do
    cmds =
      case ctx.update do
        {:message, msg} -> CuteFemBot.Util.find_all_commands(msg)
        _ -> []
      end

    {:cont, Map.put(ctx, :commands, cmds)}
  end

  def handle_unban_commands(ctx) do
    case ctx.commands do
      %{"unban" => _} ->
        # listing unban commands
        command_unban(ctx)
        :halt

      cmds ->
        # looking for unban_{user_id} commands
        unban_user_ids =
          Stream.map(cmds, fn {cmd_name, _} -> cmd_name end)
          |> CuteFemBot.Logic.Util.find_particular_unban_commands_as_ids()

        if length(unban_user_ids) > 0 do
          Enum.each(unban_user_ids, fn id ->
            Persistence.unban_user(Ctx.deps_persistence(ctx), id)
          end)

          unbanned_formatted =
            Enum.map(
              unban_user_ids,
              &Logic.Util.user_html_link_using_meta(Ctx.deps_persistence(ctx), &1)
            )
            |> Enum.join("\n")

          Shared.send_msg!(
            ctx,
            Message.with_text("""
            Разбанил:
            #{unbanned_formatted}
            """)
          )

          :halt
        else
          :cont
        end
    end
  end

  def handle_commands(ctx) do
    case ctx.commands do
      %{"help" => _} ->
        command_help(ctx)
        :halt

      %{"queue" => _} ->
        Queue.command_queue(ctx)
        :halt

      %{"schedule" => _} ->
        Schedule.command_schedule(ctx)
        :halt

      %{"cancel" => _} ->
        Shared.command_cancel(ctx)
        :halt

      _ ->
        :cont
    end
  end

  defp command_help(ctx) do
    Shared.send_msg!(ctx, Message.with_text("Ты администратор"))
  end

  defp command_unban(ctx) do
    pers = Ctx.deps_persistence(ctx)

    banned = Persistence.get_ban_list(pers) |> Enum.to_list()

    text =
      if length(banned) > 0 do
        banned_formatted =
          Enum.map(banned, fn id ->
            user_formatted = Logic.Util.user_html_link_using_meta(pers, id)
            unban_cmd = "/unban_#{id}"
            "#{user_formatted}\n#{unban_cmd}"
          end)
          |> Enum.join("\n\n")

        """
        Забаненные пользователи:

        #{banned_formatted}
        """
      else
        "Нет ни единого забаненного пользователя"
      end

    Shared.send_msg!(ctx, Message.with_text(text))
  end

  def skip(_) do
    :halt
  end
end
