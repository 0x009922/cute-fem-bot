defmodule CuteFemBot.Core.UpdatesHandlerTest do
  use ExUnit.Case

  alias CuteFemBot.Core.UpdatesHandler

  defp input_factory(opts \\ []) do
    %{
      banned_users: Keyword.get(opts, :banned_users, MapSet.new()),
      moderation_chat_id: Keyword.get(opts, :moderation_chat_id, 99),
      updates: Keyword.get(opts, :updates, [])
    }
  end

  defp user_factory(id, opts \\ []) do
    %{"id" => id, "is_bot" => false, "first_name" => "Ivan"}
  end

  defp update_factory(:message, msg) do
    %{"update_id" => 0, "message" => msg}
  end

  defp message_factory(chat, from, opts) do
    msg = %{
      "chat" => chat,
      "from" => from
    }

    msg =
      Enum.reduce(opts, msg, fn el, acc ->
        case el do
          {:photo, x} -> Map.put(acc, "photo", x)
          {:text, x} -> Map.put(acc, "text", x)
          {:video, x} -> Map.put(acc, "video", x)
          {:entities, x} -> Map.put(acc, "entities", x)
          {:document, x} -> Map.put(acc, "document", x)
        end
      end)

    msg
  end

  defp message_from_user(user, opts) do
    message_factory(%{"id" => user["id"]}, user, opts)
  end

  defp actions_factory(actions_list) do
    actions_list
  end

  test "returns empty list of actions if updates list is empty" do
    assert UpdatesHandler.handle(input_factory()) == actions_factory([])
  end

  describe "Handling suggestor input" do
    test "Welcomes suggestor in response to /start command" do
      user = user_factory(8)

      updates =
        UpdatesHandler.handle(
          input_factory(
            updates: [
              update_factory(
                :message,
                message_from_user(user,
                  text: "/start",
                  entities: [%{"type" => "bot_command", "offset" => 0, "length" => 6}]
                )
              )
            ]
          )
        )

      assert {:greet_suggestor, chat_id: 8} in updates
    end

    test "handles incoming photo" do
      user = user_factory(15)

      assert UpdatesHandler.handle(
               input_factory(
                 moderation_chat_id: 333,
                 updates: [
                   update_factory(
                     :message,
                     message_factory(%{"id" => 15}, user,
                       photo: [
                         %{"file_id" => "111"},
                         %{"file_id" => "222"},
                         %{"file_id" => "333"}
                       ]
                     )
                   )
                 ]
               )
             ) ==
               actions_factory([
                 {:update_user_meta, user: user},
                 {:reply_to_suggestor_with_thanks, chat_id: 15, accepted_media_count: 1},
                 {:create_proposal, user_id: 15, file_id: "111", type: :photo},
                 {:notify_moderation_about_proposal,
                  chat_id: 333, file_id: "111", type: :photo, suggestor: user}
               ])
    end

    test "handles incoming video" do
      user = user_factory(15)

      assert UpdatesHandler.handle(
               input_factory(
                 moderation_chat_id: 333,
                 updates: [
                   update_factory(
                     :message,
                     message_factory(%{"id" => 15}, user, video: %{"file_id" => "111"})
                   )
                 ]
               )
             ) ==
               actions_factory([
                 {:update_user_meta, user: user},
                 {:reply_to_suggestor_with_thanks, chat_id: 15, accepted_media_count: 1},
                 {:create_proposal, user_id: 15, file_id: "111", type: :video},
                 {:notify_moderation_about_proposal,
                  chat_id: 333, file_id: "111", type: :video, suggestor: user}
               ])
    end

    test "handles incoming image & video document from suggestor, but ignores pdf" do
      user = user_factory(7)

      doc_update_factory = fn doc ->
        update_factory(
          :message,
          message_factory(%{"id" => 7}, user, document: doc)
        )
      end

      assert UpdatesHandler.handle(
               input_factory(
                 moderation_chat_id: 99,
                 updates: [
                   doc_update_factory.(%{
                     "file_id" => "IMG",
                     "mime_type" => "image/jpeg"
                   }),
                   doc_update_factory.(%{
                     "file_id" => "VID",
                     "mime_type" => "video/mp4"
                   }),
                   doc_update_factory.(%{
                     "file_id" => "PDF",
                     "mime_type" => "application/pdf"
                   })
                 ]
               )
             ) ==
               actions_factory([
                 {:update_user_meta, user: user},
                 {:reply_to_suggestor_with_thanks, chat_id: 7, accepted_media_count: 2},
                 {:create_proposal, user_id: 7, file_id: "IMG", type: :document},
                 {:notify_moderation_about_proposal,
                  chat_id: 99, file_id: "IMG", type: :document, suggestor: user},
                 {:create_proposal, user_id: 7, file_id: "VID", type: :document},
                 {:notify_moderation_about_proposal,
                  chat_id: 99, file_id: "VID", type: :document, suggestor: user}
               ])
    end

    test "handles message without any media" do
      user = user_factory(15)

      assert UpdatesHandler.handle(
               input_factory(
                 updates: [
                   update_factory(:message, message_factory(%{"id" => 15}, user, text: "hey"))
                 ]
               )
             ) ==
               actions_factory([
                 {:update_user_meta, user: user},
                 {:reply_to_suggestor_that_no_media_was_found_in_his_message, chat_id: 15}
               ])
    end

    test "handles message from banned user" do
      user = user_factory(10)

      assert UpdatesHandler.handle(
               input_factory(
                 banned_users: [10],
                 updates: [
                   update_factory(
                     :message,
                     message_factory(%{"id" => 10}, user, photo: [%{"file_id" => "some id"}])
                   )
                 ]
               )
             ) ==
               actions_factory([
                 {:update_user_meta, user: user},
                 {:reply_to_suggestor_that_he_is_banned, chat_id: 10}
               ])
    end

    test "handles mixed proposals from different suggestors" do
      user_a = user_factory(10)
      user_b = user_factory(20)

      assert UpdatesHandler.handle(
               input_factory(
                 moderation_chat_id: 333,
                 updates: [
                   update_factory(
                     :message,
                     message_factory(%{"id" => 10}, user_a, photo: [%{"file_id" => "photo 1"}])
                   ),
                   update_factory(
                     :message,
                     message_factory(%{"id" => 20}, user_b, photo: [%{"file_id" => "photo 2"}])
                   )
                 ]
               )
             ) ==
               actions_factory([
                 {:update_user_meta, users: [user_a, user_b]},
                 {:reply_to_suggestor_with_thanks, chat_id: 10, accepted_media_count: 1},
                 {:create_proposal, user_id: 10, file_id: "photo 1", type: :photo},
                 {:notify_moderation_about_proposal,
                  chat_id: 333, file_id: "photo 1", type: :photo, suggestor: user_a},
                 {:reply_to_suggestor_with_thanks, chat_id: 20, accepted_media_count: 1},
                 {:create_proposal, user_id: 20, file_id: "photo 2", type: :photo},
                 {:notify_moderation_about_proposal,
                  chat_id: 333, file_id: "photo 2", type: :photo, suggestor: user_b}
               ])
    end

    test "handles mixed proposals from different suggestors (one of them is banned)" do
      user_a = user_factory(10)
      user_b = user_factory(20)

      assert UpdatesHandler.handle(
               input_factory(
                 moderation_chat_id: 333,
                 banned_users: [10],
                 updates: [
                   update_factory(
                     :message,
                     message_factory(%{"id" => 10}, user_a, photo: [%{"file_id" => "photo 1"}])
                   ),
                   update_factory(
                     :message,
                     message_factory(%{"id" => 20}, user_b, photo: [%{"file_id" => "photo 2"}])
                   )
                 ]
               )
             ) ==
               actions_factory([
                 {:update_user_meta, users: [user_a, user_b]},
                 {:reply_to_suggestor_that_he_is_banned, chat_id: 10},
                 {:reply_to_suggestor_with_thanks, chat_id: 20, accepted_media_count: 1},
                 {:create_proposal, user_id: 20, file_id: "photo 2", type: :photo},
                 {:notify_moderation_about_proposal,
                  chat_id: 333, file_id: "photo 2", type: :photo, suggestor: user_b}
               ])
    end

    test "handles multiple proposals from a single suggestor at once" do
      user = user_factory(15)

      assert UpdatesHandler.handle(
               input_factory(
                 moderation_chat_id: 333,
                 updates: [
                   update_factory(
                     :message,
                     message_factory(%{"id" => 15}, user,
                       photo: [
                         %{"file_id" => "img"}
                       ]
                     )
                   ),
                   update_factory(
                     :message,
                     message_factory(%{"id" => 15}, user, video: %{"file_id" => "vid"})
                   )
                 ]
               )
             ) ==
               actions_factory([
                 {:update_user_meta, user: user},
                 {:reply_to_suggestor_with_thanks, chat_id: 15, accepted_media_count: 2},
                 {:create_proposal, user_id: 15, file_id: "img", type: :photo},
                 {:notify_moderation_about_proposal,
                  chat_id: 333, file_id: "img", type: :photo, suggestor: user},
                 {:create_proposal, user_id: 15, file_id: "vid", type: :video},
                 {:notify_moderation_about_proposal,
                  chat_id: 333, file_id: "vid", type: :video, suggestor: user}
               ])
    end
  end

  describe "Handling moderation input" do
    test "handles approval of proposal" do
      # TODO
    end

    test "handles rejection of proposal" do
      # TODO
    end

    test "handles user ban" do
      # TODO
    end

    test "handles schedule view request" do
      # TODO
    end

    test "handles schedule change request" do
      # TODO
    end
  end
end
