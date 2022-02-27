defmodule CuteFemBot.Logic.Handler.SuggestionsAdmin do
  alias CuteFemBot.Persistence
  alias Telegram.Api
  alias Telegram.Types.Message
  alias CuteFemBot.Logic.Handler
  alias Handler.Ctx
  alias CuteFemBot.Core.Suggestion

  def main() do
    [:handle_suggestions_callbacks]
  end

  def handle_suggestions_callbacks(ctx) do
    with {:callback_query,
          %{
            "id" => query_id,
            "message" => %{"message_id" => query_msg_id},
            "data" => query_data
          }} <- ctx.update,
         {:ok, %Suggestion{} = suggestion} <-
           find_suggestion_msg(query_msg_id) do
      Api.answer_callback_query(Ctx.deps_api(ctx), query_id)

      query_parsed = CuteFemBot.Logic.Suggestions.suggestion_btn_data_to_key(query_data)

      suggestion_callback_answer = fn action ->
        actor_formatted = ctx_format_source_user(ctx)

        action_text =
          case action do
            :approve_sfw -> "ня"
            :approve_nsfw -> "NSFW-ня"
            :reject -> "не ня"
            :ban -> "бан"
          end

        text = "#{actor_formatted}: #{action_text}"

        # send action result
        Api.send_message(
          Ctx.deps_api(ctx),
          Message.with_text(text)
          |> Message.set_reply_to(query_msg_id)
          |> Message.set_chat_id(Ctx.cfg_get_suggestions_chat(ctx))
          |> Message.set_parse_mode("html")
        )

        # delete reply markup
        Api.request(Ctx.deps_api(ctx),
          method_name: "editMessageReplyMarkup",
          body: %{
            "chat_id" => Ctx.cfg_get_suggestions_chat(ctx),
            "message_id" => query_msg_id
          }
        )
      end

      case query_parsed do
        :error ->
          nil

        {:ok, action} ->
          %Suggestion{file_id: file_id, user_id: user_id} = suggestion

          case action do
            x when x == :approve_sfw or x == :approve_nsfw ->
              category =
                case x do
                  :approve_sfw -> :sfw
                  :approve_nsfw -> :nsfw
                end

              Persistence.approve_media(file_id, category)

            :reject ->
              Persistence.reject_media(file_id)

            :ban ->
              Persistence.ban_user(user_id)
          end

          suggestion_callback_answer.(action)
      end

      :halt
    else
      _ -> :cont
    end
  end

  defp ctx_format_source_user(ctx) do
    %{source: %{user: user}} = ctx
    CuteFemBot.Util.format_user_name(user, :html)
  end

  defp find_suggestion_msg(msg_id) do
    Persistence.find_suggestion_by_moderation_msg(msg_id)
  end
end
