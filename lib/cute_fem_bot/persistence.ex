defmodule CuteFemBot.Persistence do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

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

  @impl true
  def handle_call({:update_user_meta, %{"id" => id} = new_user}, _from, state) do
    {:reply, :ok, Map.update!(state, :users_meta, fn map -> Map.put(map, id, new_user) end)}
  end

  def handle_call(
        {:new_suggestion, %{user_id: _, type: _, file_id: _} = data, moderation_message_id},
        _from,
        state
      ) do
    {
      :reply,
      :ok,
      Map.update!(state, :unapproved_queue, fn queue ->
        queue ++ [data |> Map.put(:moderation_message_id, moderation_message_id)]
      end)
    }
  end

  def handle_call(:get_ban_list, _from, %{banned: banned} = state) do
    {:reply, banned, state}
  end

  def handle_call({:get_user_meta, user_id}, _from, %{users_meta: users_meta} = state) do
    {:reply,
     case users_meta do
       %{^user_id => data} -> {:ok, data}
       _ -> :not_found
     end, state}
  end

  def handle_call({:ban_user, user_id}, _, state) do
    {
      :reply,
      :ok,
      Map.update!(state, :banned, fn set -> MapSet.put(set, user_id) end)
    }
  end

  def handle_call({:unban_user, user_id}, _, state) do
    {
      :reply,
      :ok,
      Map.update!(state, :banned, fn set -> MapSet.delete(set, user_id) end)
    }
  end

  # Client API

  def update_user_meta(pers, data) do
    GenServer.call(pers, {:update_user_meta, data})
  end

  def get_user_meta(pers, id) do
    GenServer.call(pers, {:get_user_meta, id})
  end

  def add_new_suggestion(pers, media, moderation_message_id) do
    GenServer.call(pers, {:new_suggestion, media, moderation_message_id})
  end

  # def approve_media(pers, file_id) do
  # end

  # def reject_media(pers, file_id) do
  # end

  # def get_unapproved_queue() do
  # end

  # def get_approved_queue() do
  # end

  def get_ban_list(pers) do
    GenServer.call(pers, :get_ban_list)
  end

  @spec ban_user(atom | pid | {atom, any} | {:via, atom, any}, any) :: any
  def ban_user(pers, user_id) do
    GenServer.call(pers, {:ban_user, user_id})
  end

  def unban_user(pers, user_id) do
    GenServer.call(pers, {:unban_user, user_id})
  end

  # def approved_media_posted(pers, media, file_id, posted_message_id) do
  #   GenServer.call(pers, {:approved_media_posted, media, file_id, posted_message_id})
  # end

  # def commit_post_rate(file_id, user_id, vote) do
  #   # vote is :like or :dislike
  #   # returns total count of likes and dislikes for the post
  # end
end
