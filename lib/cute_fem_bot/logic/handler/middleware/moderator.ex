defmodule CuteFemBot.Logic.Handler.Middleware.Moderator do
  @moduledoc """
  Implying that if context enters this module it means that message from moderation for sure
  """

  alias CuteFemBot.Telegram.Types.Message
  alias CuteFemBot.Telegram.Api
  alias CuteFemBot.Persistence
  alias CuteFemBot.Logic.Handler.Ctx
  alias CuteFemBot.Logic

  import __MODULE__.Shared
  alias __MODULE__.Queue
  alias __MODULE__.Schedule

  require Logger

  def main() do
    [
      :handle_suggestions_callbacks,
      :fetch_chat_state,
      :find_commands_in_message,
      :handle_unban_commands,
      :handle_commands,
      :handle_queue,
      :handle_schedule,
      :skip
    ]
  end

  @spec fetch_chat_state(%{
          :deps =>
            atom
            | %{
                :persistence => atom | pid | {atom, any} | {:via, atom, any},
                optional(any) => any
              },
          optional(any) => any
        }) ::
          {:cont,
           %{
             :deps =>
               atom
               | %{
                   :persistence => atom | pid | {any, any} | {any, any, any},
                   optional(any) => any
                 },
             :moderation_chat_state => any,
             optional(any) => any
           }}
  def fetch_chat_state(ctx) do
    state = CuteFemBot.Persistence.get_moderation_chat_state(ctx.deps.persistence)
    {:cont, Map.put(ctx, :moderation_chat_state, state)}
  end

  @spec find_commands_in_message(%{:update => any, optional(any) => any}) ::
          {:cont, %{:commands => any, :update => any, optional(any) => any}}
  def find_commands_in_message(ctx) do
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
          |> Stream.map(fn cmd_name ->
            case Regex.scan(~r{^unban_(\d+)$}, cmd_name) do
              [[_, user_id]] -> {:uid, String.to_integer(user_id)}
              _ -> :none
            end
          end)
          |> Stream.filter(fn parsed -> parsed != :none end)
          |> Stream.map(fn {:uid, id} -> id end)
          |> Enum.to_list()

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

          send_msg!(
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
      %{"queue" => _} ->
        Queue.command_queue(ctx)
        :halt

      %{"schedule" => _} ->
        Schedule.command_schedule(ctx)
        :halt

      %{"cancel" => _} ->
        command_cancel(ctx)
        :halt

      _ ->
        :cont
    end
  end

  def handle_suggestions_callbacks(ctx) do
    with {:callback_query,
          %{
            "id" => query_id,
            "message" => %{"message_id" => query_msg_id},
            "data" => query_data
          }} <- ctx.update,
         {:ok, %{file_id: file_id, user_id: user_id}} <-
           find_suggestion_msg(ctx, query_msg_id) do
      Api.answer_callback_query(Ctx.deps_api(ctx), query_id)

      query_parsed =
        case query_data do
          "approve" -> {:ok, :approve}
          "reject" -> {:ok, :reject}
          "ban" -> {:ok, :ban}
          _ -> :error
        end

      suggestion_callback_answer = fn action ->
        # reply to message
        # edit message reply markup

        text =
          case action do
            :approve -> "ОК, добавил в очередь"
            :reject -> "ОК, мимо"
            :ban -> "ОК, забанен"
          end

        send_msg!(ctx, Message.with_text(text) |> Message.set_reply_to(query_msg_id))

        Api.request!(Ctx.deps_api(ctx),
          method_name: "editMessageReplyMarkup",
          body: %{
            "chat_id" => ctx.config.moderation_chat_id,
            "message_id" => query_msg_id
          }
        )
      end

      case query_parsed do
        :error ->
          nil

        {:ok, action} ->
          case action do
            :approve ->
              Persistence.approve_media(Ctx.deps_persistence(ctx), file_id)

            :reject ->
              Persistence.reject_media(Ctx.deps_persistence(ctx), file_id)

            :ban ->
              Persistence.ban_user(Ctx.deps_persistence(ctx), user_id)
          end

          suggestion_callback_answer.(action)
      end

      :halt
    else
      _ -> :cont
    end
  end

  def handle_schedule(ctx) do
    {:cont, :sub_mod, Schedule, ctx}
  end

  def handle_queue(ctx) do
    {:cont, :sub_mod, Queue, ctx}
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
            "#{user_formatted} #{unban_cmd}"
          end)

        """
        Забаненные пользователи:

        #{banned_formatted}
        """
      else
        "Нет ни единого забаненного пользователя"
      end

    send_msg!(ctx, Message.with_text(text))
  end

  defp find_suggestion_msg(ctx, msg_id) do
    Persistence.find_suggestion_by_moderation_msg(Ctx.deps_persistence(ctx), msg_id)
  end

  def skip(_) do
    :halt
  end
end
