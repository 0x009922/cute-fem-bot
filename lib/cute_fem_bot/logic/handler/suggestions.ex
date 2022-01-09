defmodule CuteFemBot.Logic.Handler.Suggestions do
  alias CuteFemBot.Telegram.Types.Message
  alias CuteFemBot.Telegram.Api
  alias CuteFemBot.Persistence
  alias CuteFemBot.Core.Suggestion
  alias CuteFemBot.Logic
  alias Logic.Speaking
  alias Logic.Handler.Ctx

  def main() do
    [
      :banlist_guard,
      :handle_commands,
      :handle_suggestion
    ]
  end

  def banlist_guard(ctx) do
    ban_list = Persistence.get_ban_list(Ctx.deps_persistence(ctx))

    if ctx_get_user_id(ctx) in ban_list do
      case ctx.update do
        {:message, _} ->
          reply_ignore!(ctx)

        _ ->
          nil
      end

      :halt
    else
      :cont
    end
  end

  def handle_commands(ctx) do
    case ctx.update do
      {:message, msg} ->
        cmds = CuteFemBot.Util.find_all_commands(msg)

        if Map.has_key?(cmds, "start") or Map.has_key?(cmds, "help") do
          send_msg!(
            ctx,
            Message.with_text(
              CuteFemBot.Logic.Speaking.msg_suggestions_welcome(ctx_get_lang(ctx))
            )
          )

          :halt
        else
          :cont
        end

      _ ->
        :cont
    end
  end

  def handle_suggestion(ctx) do
    case ctx.update do
      {:message, msg} ->
        case Suggestion.extract_from_message(msg) do
          :none ->
            reply_media_not_found!(ctx)
            :halt

          {:ok, %Suggestion{} = item} ->
            case Persistence.find_existing_unapproved_suggestion_by_file_id(
                   Ctx.deps_persistence(ctx),
                   item.file_id
                 ) do
              :not_found ->
                :ok =
                  Persistence.add_new_suggestion(
                    Ctx.deps_persistence(ctx),
                    item
                  )

                msg_id = send_suggestion_to_admins!(ctx, item)

                :ok =
                  Persistence.bind_moderation_msg_to_suggestion(
                    Ctx.deps_persistence(ctx),
                    item.file_id,
                    msg_id
                  )

                reply_with_thx!(ctx)

              _ ->
                nil
            end

            :halt
        end

      _ ->
        :cont
    end
  end

  defp reply_ignore!(ctx) do
    send_stick!(
      ctx,
      Message.with_sticker(Speaking.sticker_ignore())
      |> Message.set_reply_to(ctx_get_msg_id(ctx), true)
    )
  end

  defp reply_media_not_found!(ctx) do
    send_msg!(
      ctx,
      Message.with_text(Speaking.msg_suggestions_no_media(ctx_get_lang(ctx)))
      |> Message.set_reply_to(ctx_get_msg_id(ctx), true)
    )
  end

  defp reply_with_thx!(ctx) do
    send_stick!(
      ctx,
      Message.with_sticker(Speaking.sticker_suggestion_accepted())
      |> Message.set_reply_to(ctx_get_msg_id(ctx), true)
    )
  end

  defp ctx_get_msg(%{update: {:message, msg}}), do: msg

  defp ctx_get_msg_id(ctx) do
    %{"message_id" => id} = ctx_get_msg(ctx)
    id
  end

  defp ctx_get_user(%{source: %{user: user}}), do: user

  defp ctx_get_user_id(ctx) do
    %{"id" => id} = ctx_get_user(ctx)
    id
  end

  defp ctx_get_lang(%{source: %{lang: x}}), do: x

  defp send_suggestion_to_admins!(ctx, %Suggestion{} = item) do
    {caption, caption_entities} = admins_suggestions_msg_caption(ctx)

    %{method_name: method, body_part: media_body_part} = Suggestion.to_send(item)

    btns =
      [:approve, :reject, :ban]
      |> Enum.map(fn key ->
        caption =
          case key do
            :approve -> "Ня"
            :reject -> "Не ня"
            :ban -> "Бан"
          end

        inline_reply_btn(caption, Logic.Suggestions.suggestion_btn_key_to_data(key))
      end)

    %{"message_id" => msg_id} =
      Api.request!(
        Ctx.deps_api(ctx),
        method_name: method,
        body:
          %{
            "chat_id" => Ctx.cfg_get_suggestions_chat(ctx),
            "caption" => caption,
            "caption_entities" => caption_entities,
            "parse_mode" => "html",
            "reply_markup" => %{"inline_keyboard" => [btns]}
          }
          |> Map.merge(media_body_part)
      )

    msg_id
  end

  defp admins_suggestions_msg_caption(ctx) do
    # TODO forward user caption entities (i.e. formatting)

    user_formatted = CuteFemBot.Util.format_user_name(ctx.source.user, :html)
    caption_base = "Предложка от #{user_formatted}"

    {:message, msg} = ctx.update
    user_caption = Map.get(msg, "caption", "")

    caption =
      if String.length(user_caption) > 0 do
        """
        #{caption_base}

        ---

        #{user_caption}
        """
      else
        caption_base
      end

    {caption, []}
  end

  defp inline_reply_btn(text, callback_data) do
    %{"text" => text, "callback_data" => callback_data}
  end

  defp send_stick!(ctx, body) do
    Api.request!(
      Ctx.deps_api(ctx),
      method_name: "sendSticker",
      body: Message.new() |> Message.set_chat_id(ctx_get_user_id(ctx)) |> Map.merge(body)
    )
  end

  defp send_msg!(ctx, body) do
    {:ok, x} =
      Api.send_message(
        Ctx.deps_api(ctx),
        Message.new()
        |> Message.set_chat_id(ctx_get_user_id(ctx))
        |> Message.set_parse_mode("html")
        |> Map.merge(body)
      )

    x
  end
end
