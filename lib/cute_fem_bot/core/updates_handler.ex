defmodule CuteFemBot.Core.UpdatesHandler do
  @moduledoc """
  This module is the entry point for raw Telegram Updates.
  It countains pure deterministic logic of handling this updates.
  """

  @doc """
  Returns the list of actions to do
  """
  def handle(%{updates: []}) do
    []
  end

  def handle(%{banned_users: banned, moderation_chat_id: mod_id, updates: updates}) do
    msgs = extract_messages(updates)
    {_moderation_msgs, suggestors_msgs} = group_messages(msgs, mod_id)

    update_user_meta_action = compute_update_user_meta_by_suggestors_map(suggestors_msgs)

    suggestor_actions =
      Enum.flat_map(suggestors_msgs, fn {user, msgs} ->
        handle_suggestor_msgs(user, msgs, banned, mod_id)
      end)

    [update_user_meta_action] ++ suggestor_actions
  end

  defp group_messages(msgs, moderation_chat_id) do
    Enum.reduce(msgs, {[], %{}}, fn msg, {moderation, suggestors} ->
      case msg do
        %{"chat" => %{"id" => ^moderation_chat_id}} ->
          {moderation ++ msg, suggestors}

        %{"from" => user} ->
          # suggestor message
          {moderation,
           if Map.has_key?(suggestors, user) do
             Map.update!(suggestors, user, fn msgs -> msgs ++ [msg] end)
           else
             Map.put(suggestors, user, [msg])
           end}
      end
    end)
  end

  defp handle_suggestor_msgs(%{"id" => user_id} = user, msgs, banned_list, moder_id) do
    if user_id in banned_list do
      # chat_id = find_some_chat_id_from_messages(msgs)
      [{:reply_to_suggestor_that_he_is_banned, chat_id: user_id}]
    else
      # not banned

      # looking for a /start command
      greeting =
        cond do
          is_there_the_start_command?(msgs) -> {:greet_suggestor, chat_id: user_id}
          true -> nil
        end

      # searching for postable media
      media = find_postable_media(msgs)

      media_actions =
        Stream.flat_map(media, fn media_item ->
          {type, file_id} = media_item

          [
            {:create_proposal, user_id: user_id, file_id: file_id, type: type},
            {:notify_moderation_about_proposal,
             chat_id: moder_id, file_id: file_id, type: type, suggestor: user}
          ]
        end)
        |> Enum.to_list()

      media_actions =
        case media_actions do
          [] ->
            []

          main_actions ->
            [
              {:reply_to_suggestor_with_thanks,
               chat_id: user_id, accepted_media_count: length(media)}
              | main_actions
            ]
        end

      # resulting actions
      case {greeting, media_actions} do
        {nil, []} ->
          [{:reply_to_suggestor_that_no_media_was_found_in_his_message, chat_id: user_id}]

        {nil, _} ->
          media_actions

        _ ->
          [greeting | media_actions]
      end
    end
  end

  defp extract_messages(updates) do
    updates
    |> Stream.filter(fn x ->
      case x do
        %{"message" => _} -> true
        _ -> false
      end
    end)
    |> Stream.map(fn %{"message" => msg} -> msg end)
    |> Enum.to_list()
  end

  defp compute_update_user_meta_by_suggestors_map(suggestors) do
    # just going through updates and collecting "from" to a map

    users_map =
      Enum.reduce(suggestors, %{}, fn {%{"id" => id} = user, _}, acc ->
        Map.put(acc, id, user)
      end)

    if map_size(users_map) == 1 do
      [user] = Map.values(users_map)
      {:update_user_meta, user: user}
    else
      {:update_user_meta, users: Map.values(users_map)}
    end
  end

  defp find_some_chat_id_from_messages(msgs) do
    # if there is private chat id, returns it
    # otherwise returns some of the chat_id in msgs
    case Enum.find(msgs, fn x ->
           case x do
             %{"chat" => %{"type" => "private", "id" => chat_id}} -> chat_id
             _ -> false
           end
         end) do
      nil ->
        [%{"chat" => %{"id" => chat_id}} | _] = msgs
        chat_id

      chat_id ->
        chat_id
    end
  end

  defp is_there_the_start_command?(msgs) do
    Enum.find(msgs, nil, fn msg ->
      case msg do
        %{"text" => "/start"} -> true
        _ -> false
      end
    end) != nil
  end

  defp find_postable_media(msgs) do
    Enum.reduce(msgs, [], fn msg, media ->
      case msg do
        %{"photo" => [%{"file_id" => file_id} | _]} ->
          media ++ [{:photo, file_id}]

        %{"video" => %{"file_id" => file_id}} ->
          media ++ [{:video, file_id}]

        %{"document" => %{"mime_type" => mime, "file_id" => file_id}} ->
          if mime =~ ~r{^(image|video)\/} do
            media ++ [{:document, file_id}]
          else
            media
          end

        _ ->
          media
      end
    end)
  end
end
