defmodule CuteFemBot.Core.UpdatesHandlerTest do
  use ExUnit.Case

  alias CuteFemBot.Core.UpdatesHandler
  alias UpdatesHandler.Input
  alias UpdatesHandler.Output
  alias CuteFemBot.Tg.Types

  test "returns empty list of actions if updates list is empty" do
    assert UpdatesHandler.handle(%Input{
             moderation_chat_id: 441_242_341,
             banned_users: [],
             updates: []
           }) == %Output{actions: []}
  end

  test "handles incoming photo from suggestor" do
    update =
      Types.Update.parse(%{
        "update_id" => 0,
        "message" => %{
          "chat" => %{"id" => 15},
          "from" => %{"id" => 15, "is_bot" => false, "first_name" => "Ivan"},
          "photo" => [
            %{"file_id" => "111"},
            %{"file_id" => "222"},
            %{"file_id" => "333"}
          ]
        }
      })

    # getting user
    %Types.Update{value: {:message, %Types.Message{from: user}}} = update

    assert UpdatesHandler.handle(%Input{
             moderation_chat_id: 333,
             banned_users: [],
             updates: [update]
           }) == %Output{
             actions: [
               {:update_user_meta, user: user},
               {:reply_to_suggestor_with_thanks, chat_id: 15, accepted_media_count: 1},
               {:create_proposal, user_id: 15, file_id: "111", type: :photo},
               {:notify_moderation_about_proposal,
                chat_id: 333, file_id: "111", type: :photo, suggestor: user}
             ]
           }
  end

  test "handles incoming video from suggestor"

  test "handles incoming image & video document from suggestor"

  test "handles message from suggestor without any media"

  test "handles message from banned user"

  test "handles mixed proposals from different suggestors"

  test "handles mixed proposals from different suggestors (one of them is banned)"

  test "handles multiple proposals from a single suggestor at once"

  test "handles approval of proposal from moderation"

  test "handles rejection of proposal from moderation"

  test "handles user ban from moderation"

  test "handles schedule view request from moderation"

  test "handles schedule change request from moderation"
end
