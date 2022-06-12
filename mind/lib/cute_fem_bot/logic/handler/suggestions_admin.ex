defmodule CuteFemBot.Logic.Handler.SuggestionsAdmin do
  alias CuteFemBot.Persistence
  alias Telegram.Api
  alias Telegram.Types.Message
  alias CuteFemBot.Logic.Handler
  alias Handler.Context
  alias CuteFemBot.Schema.Suggestion

  @behaviour Traffic.Point
  import Traffic.Context

  @impl true
  def handle(ctx) do
    with {:callback_query,
          %{
            "id" => query_id,
            "message" => %{"message_id" => query_msg_id} = query_msg,
            "data" => query_data
          }} <- Context.get_parsed_update!(ctx),
         {:ok, %Suggestion{} = suggestion} <-
           find_suggestion_msg(query_msg_id) do
      Api.answer_callback_query(Context.get_dep!(ctx, :telegram), query_id)

      query_parsed = CuteFemBot.Logic.Suggestions.suggestion_btn_data_to_key(query_data)

      case query_parsed do
        :error ->
          nil

        {:ok, action} ->
          %Suggestion{file_id: file_id, made_by: suggestion_made_by} = suggestion
          admin_user = Context.get_update_source!(ctx, :user)
          %{"id" => admin_id} = admin_user

          {decision, ban?} =
            case action do
              :approve_sfw -> {:sfw, false}
              :approve_nsfw -> {:nsfw, false}
              :reject -> {:reject, false}
              :ban -> {:reject, true}
            end

          Persistence.make_decision(file_id, admin_id, DateTime.utc_now(), decision)
          if ban?, do: Persistence.ban_user(suggestion_made_by)

          edit_message_body =
            CuteFemBot.Logic.Handler.Util.construct_suggestion_final_edit_caption_message(%{
              user: admin_user,
              suggestion_msg: query_msg,
              action: action
            })
            |> Message.set_chat_id(Context.get_config_suggestions_chat!(ctx))
            |> Map.put("message_id", query_msg_id)

          # send action result
          Api.request(
            Context.get_dep!(ctx, :telegram),
            method_name: "editMessageCaption",
            body: edit_message_body
          )

          # delete reply markup
          Api.request(
            Context.get_dep!(ctx, :telegram),
            method_name: "editMessageReplyMarkup",
            body: %{
              "chat_id" => Context.get_config_suggestions_chat!(ctx),
              "message_id" => query_msg_id
            }
          )
      end

      halt(ctx)
    else
      _ -> ctx
    end
  end

  defp find_suggestion_msg(msg_id) do
    Persistence.find_suggestion_by_moderation_msg(msg_id)
  end
end
