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
            "message" => %{"message_id" => query_msg_id} = query_msg,
            "data" => query_data
          }} <- ctx.update,
         {:ok, %Suggestion{} = suggestion} <-
           find_suggestion_msg(query_msg_id) do
      Api.answer_callback_query(Ctx.deps_api(ctx), query_id)

      query_parsed = CuteFemBot.Logic.Suggestions.suggestion_btn_data_to_key(query_data)

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

          edit_message_body =
            CuteFemBot.Logic.Handler.Util.construct_suggestion_final_edit_caption_message(%{
              user: ctx.source.user,
              suggestion_msg: query_msg,
              action: action
            })
            |> Message.set_chat_id(Ctx.cfg_get_suggestions_chat(ctx))
            |> Map.put("message_id", query_msg_id)

          # send action result
          Api.request(Ctx.deps_api(ctx),
            method_name: "editMessageCaption",
            body: edit_message_body
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

      :halt
    else
      _ -> :cont
    end
  end

  defp find_suggestion_msg(msg_id) do
    Persistence.find_suggestion_by_moderation_msg(msg_id)
  end
end
