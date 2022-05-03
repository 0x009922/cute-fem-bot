defmodule CuteFemBot.Logic.Handler.Admin do
  @moduledoc """
  Admin route - queue, schedule, unban
  """

  alias __MODULE__, as: Self
  alias Self.Shared
  alias Self.Schedule
  alias Telegram.Types.Message
  alias CuteFemBot.Persistence
  alias CuteFemBot.Logic
  alias CuteFemBot.Logic.Handler.Ctx

  require Logger

  def main() do
    [
      :fetch_chat_state,
      :extract_commands_from_message,
      :handle_cmd_cancel,
      :handle_posting_mode_redir,
      :handle_cmd_schedule,
      :handle_cmd_web,
      :handle_cmd_posting_mode,
      :handle_cmd_help,
      :handle_cmd_unban,
      :handle_cmd_dynamic_unban,
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

    {:cont, ctx_cmds_put(ctx, cmds)}
  end

  def handle_posting_mode_redir(ctx) do
    case Shared.chat_state(ctx) do
      :posting_mode ->
        {:cont, :sub_mod, Logic.Handler.Suggestions, ctx}

      _ ->
        :cont
    end
  end

  def handle_cmd_cancel(ctx) do
    halt_if_cmd(ctx, "cancel", fn ->
      Shared.command_cancel(ctx)
    end)
  end

  def handle_cmd_unban(ctx) do
    halt_if_cmd(ctx, "unban", fn ->
      banned = Persistence.get_ban_list() |> Enum.to_list()

      text =
        if length(banned) > 0 do
          banned_formatted =
            Enum.map(banned, fn id ->
              user_formatted = Logic.Util.user_html_link_using_meta(id)
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
    end)
  end

  def handle_cmd_dynamic_unban(ctx) do
    cmds = ctx_cmds_fetch!(ctx)

    unban_user_ids =
      Stream.map(cmds, fn {cmd_name, _} -> cmd_name end)
      |> CuteFemBot.Logic.Util.find_particular_unban_commands_as_ids()

    if length(unban_user_ids) > 0 do
      Enum.each(unban_user_ids, fn id ->
        Persistence.unban_user(id)
      end)

      unbanned_formatted =
        Enum.map(
          unban_user_ids,
          &Logic.Util.user_html_link_using_meta(&1)
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

  def handle_cmd_web(ctx) do
    halt_if_cmd(ctx, "web", fn ->
      %{source: %{user: %{"id" => uid}}, config: %CuteFemBot.Config{} = cfg} = ctx

      {:ok, key, _expires_at} = CuteFemBotWeb.Auth.create_key(Ctx.deps_web_auth(ctx), uid)

      invite_path = (cfg.www_path || "") <> "/" <> key

      msg =
        if invite_path =~ ~r{localhost} do
          Message.with_text("""
          [локалхост линк](#{invite_path})

          `#{key}`
          """)
          |> Message.set_parse_mode("markdown")
        else
          Message.with_text("""
          Жми кнопку

          Открыть вне телеги: <a href="#{invite_path}">линк</a>

          Debug-ключ: <code>#{key}</code>
          """)
          |> Message.set_parse_mode("html")
          |> Message.set_reply_markup(
            :reply_keyboard_markup,
            [
              [
                %{
                  "text" => "Открыть веб",
                  "web_app" => %{
                    "url" => invite_path
                  }
                }
              ]
            ],
            one_time: true
          )
        end

      Shared.send_msg!(ctx, msg)
    end)
  end

  def handle_cmd_schedule(ctx) do
    halt_if_cmd(ctx, "schedule", fn ->
      Schedule.command_schedule(ctx)
    end)
  end

  def handle_cmd_posting_mode(ctx) do
    halt_if_cmd(ctx, "posting_mode", fn ->
      Shared.set_chat_state!(ctx, :posting_mode)

      Shared.send_msg!(
        ctx,
        Message.with_text(
          "ОК. Можешь отправить мне милых мальчиков. Когда закончишь, просто вызови /cancel"
        )
      )
    end)
  end

  def handle_cmd_help(ctx) do
    halt_if_cmd(ctx, "help", fn ->
      Shared.send_msg!(ctx, Message.with_text("Ты администратор"))
    end)
  end

  def skip(_) do
    :halt
  end

  defp ctx_cmds_put(ctx, data) do
    Map.put(ctx, :commands, data)
  end

  defp ctx_cmds_fetch!(ctx) do
    Map.fetch!(ctx, :commands)
  end

  defp ctx_cmds_is_there?(ctx, command_name) when is_map(ctx.commands) do
    Map.has_key?(ctx.commands, command_name)
  end

  defp ctx_cmds_is_there?(ctx, command_name) do
    command_name in ctx.commands
  end

  defp halt_if_cmd(ctx, cmd_name, fun) do
    if ctx_cmds_is_there?(ctx, cmd_name) do
      fun.()
      :halt
    else
      :cont
    end
  end
end
