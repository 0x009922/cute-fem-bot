defmodule CuteFemBot.Logic.Handler.Middleware.CallbackQuery do
  def main() do
    [
      :extract_callback_query,
      :try_handle_moderation_reply_to_suggestion,
      :answer_anyway
    ]
  end

  def extract_callback_query(%{update: %{"callback_query" => x}} = ctx) do
    {:cont, Map.put(ctx, :callback_query, x)}
  end

  def try_extract_inline_callback_query(update, _ctx) do
    case update do
      %{"inline_callback_query" => x} ->
        {
          :next,
          data: x,
          sub_branch: [
            :try_handle_moderation_reply_to_suggestion,
            :try_handle_posting_channel_votes
          ]
        }
    end
  end

  def try_handle_moderation_reply_to_suggestion(
        %{config: %CuteFemBot.Config{moderation_chat_id: mod_chat_id}, callback_query: query} =
          ctx
      ) do
    case query do
      %{
        "id" => query_id,
        "message" => %{
          "message_id" => msg_id,
          "chat" => %{
            "id" => ^mod_chat_id
          }
        },
        "data" => callback_data
      } ->
        case CuteFemBot.Persistence.find_suggestion_by_moderation_msg(
               ctx.deps.persistence,
               msg_id
             ) do
          :not_found ->
            :cont

          {:ok, %{file_id: fid, user_id: uid}} ->
            answer_and_delete! = fn text ->
              answer!(ctx.deps.api, query_id, text)
              CuteFemBot.Telegram.Api.delete_message!(ctx.deps.api, mod_chat_id, msg_id)
            end

            case callback_data do
              "approve" ->
                case CuteFemBot.Persistence.approve_media(ctx.deps.persistence, fid) do
                  :ok ->
                    # TODO touch scheduler
                    answer_and_delete!.("Аппрувнул ^_^")

                  :not_found ->
                    answer_no_info_about_img!(ctx.deps.api, query_id)
                end

                :halt

              "reject" ->
                case CuteFemBot.Persistence.reject_media(ctx.deps.persistence, fid) do
                  :ok ->
                    answer_and_delete!.("Окей, отвергли...")

                  :not_found ->
                    answer_no_info_about_img!(ctx.deps.api, query_id)
                end

                :halt

              "ban" ->
                :ok = CuteFemBot.Persistence.ban_user(ctx.deps.persistence, uid)
                answer_and_delete!.("Забанен")
                :halt

              unknown ->
                answer!(ctx.deps.api, query_id, "Не знаю, что это значит: #{unknown}")
                :halt
            end
        end

      _ ->
        :cont
    end
  end

  def answer_anyway(ctx) do
    answer!(ctx.deps.api, ctx.callback_query["id"], "Не знаю, что и ответить на этот запрос :/")

    :halt
  end

  defp answer_no_info_about_img!(api, query_id) do
    answer!(api, query_id, "Хм, у меня нет данных по этой картинке o_o")
  end

  defp answer!(api, query_id, text) do
    CuteFemBot.Telegram.Api.request!(
      api,
      method_name: "answerCallbackQuery",
      body: %{
        "callback_query_id" => query_id,
        "text" => text
      }
    )
  end
end
