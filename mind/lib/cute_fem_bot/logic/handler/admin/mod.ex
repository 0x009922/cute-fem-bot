defmodule CuteFemBot.Logic.Handler.Admin do
  @moduledoc """
  Admin route - queue, schedule, unban
  """

  alias CuteFemBot.Logic.Handler.Admin, as: Self
  alias Self.Shared
  alias Self.Schedule
  alias Telegram.Types.Message
  alias CuteFemBot.Persistence
  alias CuteFemBot.Logic
  alias CuteFemBot.Logic.Handler.Context

  require Logger

  use Traffic.Builder
  import Logic.Handler.ContextUtils

  over(:fetch_chat_state)
  over_if_command("cancel", :command_cancel)
  over(:posting_mode_redir)
  over_if_command("schedule", &Schedule.command_schedule/1)
  over(Schedule)
  over_if_command("web", :command_web)
  over_if_command("posting_mode", :command_posting_mode)
  over_if_command("help", :command_help)
  over_if_command("unban", :command_unban)
  over(:try_handle_dynamic_unban)
  over(&halt/1)

  def fetch_chat_state(ctx) do
    state = CuteFemBot.Persistence.get_chat_state("admin-#{Shared.get_admin_id!(ctx)}")

    ctx
    |> Context.put_admin_chat_state(state)
  end

  def command_cancel(ctx) do
    is_there_any? =
      case Context.get_admin_chat_state!(ctx) do
        nil -> false
        _ -> true
      end

    Shared.set_chat_state!(ctx, nil)

    Shared.send_msg!(
      ctx,
      Message.with_text(
        if is_there_any?, do: "ОК, отменил", else: "ОК, отменил (а было ли что?..)"
      )
      |> Message.remove_reply_keyboard()
    )

    halt(ctx)
  end

  def posting_mode_redir(ctx) do
    case Context.get_admin_chat_state!(ctx) do
      :posting_mode -> Traffic.move_on(ctx, [Logic.Handler.Suggestions])
      _ -> ctx
    end
  end

  def command_unban(ctx) do
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
    halt(ctx)
  end

  def try_handle_dynamic_unban(ctx) do
    case Context.get_message_commands(ctx) do
      nil ->
        ctx

      cmds ->
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

          halt(ctx)
        else
          ctx
        end
    end
  end

  def command_web(ctx) do
    cfg = Context.get_config!(ctx)
    %{"id" => uid} = Context.get_update_source!(ctx, :user)

    {:ok, key, _expires_at} = CuteFemBotWeb.Auth.create_key(Context.get_dep!(ctx, :web_auth), uid)

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
          one_time: true,
          resize: true
        )
      end

    Shared.send_msg!(ctx, msg)
    halt(ctx)
  end

  def command_posting_mode(ctx) do
    Shared.set_chat_state!(ctx, :posting_mode)

    Shared.send_msg!(
      ctx,
      Message.with_text(
        "ОК. Можешь отправить мне милых мальчиков. Когда закончишь, просто вызови /cancel"
      )
    )

    halt(ctx)
  end

  def command_help(ctx) do
    Shared.send_msg!(ctx, Message.with_text("Ты администратор"))
    halt(ctx)
  end
end
