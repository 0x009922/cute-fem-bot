defmodule CuteFemBot.Persistence do
  use GenServer

  @impl true
  def init(_) do
    {
      :ok,
      %{
        users_meta: %{},
        unapproved_queue: [],
        approved_queue: [],
        schedule: nil,
        banned: MapSet.new()
      }
    }
  end

  def handle_call({:update_user, %{"id" => id} = new_user}, state) do
    {:no_reply, Map.update!(state, :users_meta, fn map -> Map.put(map, id, new_user) end)}
  end

  def handle_call(
        {:new_suggestion, %{user_id: _, type: _, file_id: _} = data, moderation_message_id},
        state
      ) do
    {:no_reply,
     Map.update!(state, :unapproved_queue, fn queue ->
       queue ++ [data |> Map.put(:moderation_message_id, moderation_message_id)]
     end)}
  end

  def update_user_meta(pers, data) do
    GenServer.call(pers, {:update_user, data})
  end

  def add_new_suggestion(pers, media, moderation_message_id) do
    GenServer.call(pers, {:new_suggestion, media, moderation_message_id})
  end

  def approve_media(pers, file_id) do
  end

  def reject_media(pers, file_id) do
  end

  def get_unapproved_queue(pers) do
  end

  def get_approved_queue(pers) do
  end

  def get_ban_list(pers) do
  end

  def ban_user(pers, user_id) do
  end

  def unban_user(pers, user_id) do
  end

  def approved_media_posted(pers, media, file_id, posted_message_id) do
  end

  def commit_post_rate(pers, file_id, user_id, vote) do
    # vote is :like or :dislike
    # returns total count of likes and dislikes for the post
  end
end
