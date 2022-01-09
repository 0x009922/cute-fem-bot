defmodule CuteFemBot.Persistence do
  use GenServer

  alias CuteFemBot.Persistence.State
  alias CuteFemBot.Core.Suggestion

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  @impl true
  def init(_) do
    {:ok, %State{}}
  end

  @impl true
  def handle_call({:manipulate_state, fun}, _, %State{} = state) do
    {reply, %State{} = state} = fun.(state)
    {:reply, reply, state}
  end

  # Client API

  defp manipulate_state(pers, fun) do
    GenServer.call(pers, {:manipulate_state, fun})
  end

  def update_user_meta(pers, data) do
    manipulate_state(pers, fn %State{} = state ->
      {:ok, State.update_user_meta(state, data)}
    end)
  end

  @spec get_user_meta(atom | pid | {atom, any} | {:via, atom, any}, any) ::
          :not_found | {:ok, any}
  def get_user_meta(pers, id) do
    manipulate_state(pers, fn %State{} = state ->
      case State.get_user_meta(state, id) do
        {:ok, user} -> {{:ok, user}, state}
        :not_found -> {:not_found, state}
      end
    end)
  end

  def add_new_suggestion(
        pers,
        %Suggestion{} = data
      ) do
    manipulate_state(pers, fn %State{} = state ->
      State.add_suggestion(state, data)
    end)
  end

  def bind_moderation_msg_to_suggestion(
        pers,
        file_id,
        message_id
      ) do
    manipulate_state(pers, fn %State{} = state ->
      State.bind_moderation_message_to_suggestion(state, message_id, file_id)
    end)
  end

  def find_suggestion_by_moderation_msg(pers, msg_id) do
    manipulate_state(pers, fn %State{} = state ->
      {State.find_unapproved_by_moderation_message(state, msg_id), state}
    end)
  end

  def find_existing_unapproved_suggestion_by_file_id(pers, file_id) do
    manipulate_state(pers, fn %State{} = state ->
      {
        case Map.get(state.unapproved, file_id) do
          nil -> :not_found
          x -> {:ok, x}
        end,
        state
      }
    end)
  end

  def approve_media(pers, file_id) do
    manipulate_state(pers, fn %State{} = state ->
      State.approve(state, file_id)
    end)
  end

  def reject_media(pers, file_id) do
    manipulate_state(pers, fn %State{} = state ->
      State.reject(state, file_id)
    end)
  end

  def get_approved_queue(pers) do
    manipulate_state(pers, fn %State{} = state ->
      {state.approved_queue, state}
    end)
  end

  def cancel_approved(pers, file_id) do
    manipulate_state(pers, fn %State{} = state ->
      {:ok, State.cancel_approved(state, file_id)}
    end)
  end

  def files_posted(pers, files_list) do
    manipulate_state(pers, fn %State{} = state ->
      {:ok, State.files_posted(state, files_list)}
    end)
  end

  def get_ban_list(pers) do
    manipulate_state(pers, fn %State{} = state ->
      {state.banned, state}
    end)
  end

  @spec ban_user(atom | pid | {atom, any} | {:via, atom, any}, any) :: any
  def ban_user(pers, user_id) do
    manipulate_state(pers, fn %State{} = state ->
      {:ok, State.ban_user(state, user_id)}
    end)
  end

  def unban_user(pers, user_id) do
    manipulate_state(pers, fn %State{} = state ->
      {:ok, State.unban_user(state, user_id)}
    end)
  end

  def get_state(pers) do
    manipulate_state(pers, fn %State{} = state ->
      {state, state}
    end)
  end

  def put_state(pers, state) do
    manipulate_state(pers, fn _ ->
      {:ok, state}
    end)
  end

  def get_posting(pers) do
    manipulate_state(pers, fn %State{} = state ->
      {state.posting, state}
    end)
  end

  def set_posting(pers, %CuteFemBot.Core.Posting{} = value) do
    manipulate_state(pers, fn %State{} = state ->
      {:ok, %State{state | posting: value}}
    end)
  end

  def get_admin_chat_state(pers, admin_id) do
    manipulate_state(pers, fn %State{} = state ->
      {State.get_admin_chat_state(state, admin_id), state}
    end)
  end

  def set_admin_chat_state(pers, admin_id, new_state) do
    manipulate_state(pers, fn %State{} = state ->
      {:ok, State.set_admin_chat_state(state, admin_id, new_state)}
    end)
  end
end
