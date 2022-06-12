defmodule CuteFemBot.Logic.Handler.Suggestions do
  alias Telegram.Types.Message
  alias Telegram.Api
  alias CuteFemBot.Persistence
  alias CuteFemBot.Schema.Suggestion
  alias CuteFemBot.Logic
  alias Logic.Speaking
  alias Logic.Handler.Context

  use Traffic.Builder
  import Logic.Handler.ContextUtils

  over(:banlist_guard)
  over_if_command(["start", "help"], &welcome/1)
  over(:parse_suggestion)

  def banlist_guard(ctx) do
    ban_list = Persistence.get_ban_list()
    user_id = ctx_get_user_id(ctx)

    if user_id in ban_list do
      case Context.get_parsed_update!(ctx) do
        {:message, _} ->
          CuteFemBot.Logic.Stats.banned_user_acted(user_id)
          reply_ignore!(ctx)

        _ ->
          nil
      end

      halt(ctx)
    else
      ctx
    end
  end

  def welcome(ctx) do
    send_msg!(
      ctx,
      Message.with_text(CuteFemBot.Logic.Speaking.msg_suggestions_welcome(ctx_get_lang(ctx)))
    )

    halt(ctx)
  end

  def parse_suggestion(ctx) do
    case ctx.update do
      {:message, msg} ->
        case Suggestion.extract_from_message(msg) do
          :none ->
            reply_media_not_found!(ctx)
            :halt

          {:ok, %Suggestion{} = item} ->
            case Persistence.find_existing_unapproved_suggestion_by_file_id(item.file_id) do
              :not_found ->
                :ok = Persistence.add_new_suggestion(item)

                msg_id = send_suggestion_to_admins!(ctx, item)

                :ok =
                  Persistence.bind_moderation_msg_to_suggestion(
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

  # defp ctx_get_user(%{source: %{user: user}}), do: user

  defp ctx_get_user_id(ctx) do
    %{"id" => id} = Context.get_update_source!(ctx, :user)
    id
  end

  defp ctx_get_lang(%{source: %{lang: x}}), do: x

  defp send_suggestion_to_admins!(ctx, %Suggestion{} = item) do
    %{method_name: method, body_part: media_body_part} = Suggestion.to_telegram_send(item)

    {:message, msg} = ctx.update
    user_caption = Map.get(msg, "caption", "")
    user_caption_entities = Map.get(msg, "caption_entities", [])

    suggestion_message =
      Logic.Handler.Util.construct_suggestion_message_part(%{
        user: ctx.source.user,
        user_caption: user_caption,
        user_caption_entities: user_caption_entities
      })
      |> Message.set_chat_id(Context.get_config_suggestions_chat!(ctx))
      |> Map.merge(media_body_part)

    %{"message_id" => msg_id} =
      Api.request!(
        Context.get_dep!(ctx, :telegram),
        method_name: method,
        body: suggestion_message
      )

    msg_id
  end

  defp send_stick!(ctx, body) do
    Api.request!(
      Context.get_dep!(ctx, :telegram),
      method_name: "sendSticker",
      body: Message.new() |> Message.set_chat_id(ctx_get_user_id(ctx)) |> Map.merge(body)
    )
  end

  defp send_msg!(ctx, body) do
    {:ok, x} =
      Api.send_message(
        Context.get_dep!(ctx, :telegram),
        Message.new()
        |> Message.set_chat_id(ctx_get_user_id(ctx))
        |> Message.set_parse_mode("html")
        |> Map.merge(body)
      )

    x
  end
end
