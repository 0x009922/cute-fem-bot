defmodule CuteFemBot.Logic.Handler.Util do
  alias CuteFemBot.Logic
  alias Telegram.Types.Message

  @doc """
  don't forget to set chat_id!
  And media part too
  """
  def construct_suggestion_message_part(%{
        user: user,
        user_caption: user_caption,
        user_caption_entities: user_caption_entities
      }) do
    {caption, caption_entities} =
      admins_suggestions_msg_caption(user, user_caption, user_caption_entities)

    btns =
      [:approve_sfw, :approve_nsfw, :reject, :ban]
      |> Enum.map(fn key ->
        caption =
          case key do
            :approve_sfw -> "Ня (SFW)"
            :approve_nsfw -> "Ня (NSFW)"
            :reject -> "Не ня"
            :ban -> "Бан"
          end

        inline_reply_btn(caption, Logic.Suggestions.suggestion_btn_key_to_data(key))
      end)
      |> Enum.chunk_every(2)

    %{
      "caption" => caption,
      "caption_entities" => caption_entities
    }
    |> Message.set_parse_mode("html")
    |> Message.set_reply_markup(:inline_keyboard_markup, btns)
  end

  defp admins_suggestions_msg_caption(user, user_caption, user_caption_entities) do
    user_formatted = CuteFemBot.Util.format_user_name(user, :html)
    caption_add = "Предложка от #{user_formatted}"

    case user_caption do
      "" ->
        {caption_add, []}

      _something ->
        CuteFemBot.Util.concat_msg_text_with_exiting_formatted(
          user_caption,
          user_caption_entities,
          caption_add <> "\n\n===== Сообщение\n\n",
          :before
        )
    end
  end

  defp inline_reply_btn(text, callback_data) do
    %{"text" => text, "callback_data" => callback_data}
  end

  @doc """
  don't forget to set chat_id!
  """
  def construct_suggestion_final_edit_caption_message(%{
        user: user,
        action: action,
        suggestion_msg: msg
      })
      when action in [:approve_sfw, :approve_nsfw, :ban, :reject] do
    actor_formatted = CuteFemBot.Util.format_user_name(user, :html)

    action_text =
      case action do
        :approve_sfw -> "ня"
        :approve_nsfw -> "NSFW-ня"
        :reject -> "не ня"
        :ban -> "бан"
      end

    decision_text =
      """
      <b>~ Решение ~</b>

      #{actor_formatted}: #{action_text}
      """
      |> String.trim()

    {caption, caption_entities} =
      CuteFemBot.Util.concat_msg_text_with_exiting_formatted(
        msg["caption"],
        msg["caption_entities"],
        "\n\n" <> decision_text
      )

    %{"caption" => caption, "caption_entities" => caption_entities}
    |> Message.set_parse_mode("html")
  end
end
