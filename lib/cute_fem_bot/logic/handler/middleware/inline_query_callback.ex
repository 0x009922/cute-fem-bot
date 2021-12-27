defmodule CuteFemBot.Logic.Handler.Middleware.InlineQueryCallback do
  def schema() do
    %{
      main: [
        :try_handle_moderation_reply_to_suggestion,
        :try_handle_posting_channel_votes
      ]
    }
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

  def try_handle_moderation_reply_to_suggestion(%{"inline_callback_query" => a}, ctx) do
    %{config: %{moderation_chat_id: mod_id}, api: api, persistence: pers} = ctx

    # case update do
    #   # %{""}
    # end

    :next
  end

  def try_handle_posting_channel_votes(update, ctx) do
    :next
  end

  def ignore(_, _) do
    :halt
  end
end
