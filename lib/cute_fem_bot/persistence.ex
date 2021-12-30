defmodule CuteFemBot.Persistence do
  use GenServer

  alias __MODULE__.State

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  @impl true
  def init(_) do
    {:ok, %State{}}
  end

  @impl true
  def handle_call({:update_user_meta, data}, _, state) do
    {:reply, :ok, State.update_user_meta(state, data)}
  end

  def handle_call(
        {
          :new_suggestion,
          %{
            user_id: user_id,
            type: type,
            file_id: file_id
          }
        },
        _,
        state
      ) do
    case State.add_suggestion(state, file_id, type, user_id) do
      :duplication -> {:reply, :duplication, state}
      {:ok, state} -> {:reply, :ok, state}
    end
  end

  def handle_call({:bind_mod_msg, file_id, msg_id}, _, state) do
    case State.bind_moderation_message_to_suggestion(state, msg_id, file_id) do
      :not_found -> {:reply, :not_found, state}
      state -> {:reply, :ok, state}
    end
  end

  def handle_call(:get_ban_list, _from, %{banned: banned} = state) do
    {:reply, banned, state}
  end

  def handle_call({:get_user_meta, user_id}, _from, state) do
    {:reply, State.get_user_meta(state, user_id), state}
  end

  def handle_call({:ban_user, user_id}, _, state) do
    {:reply, :ok, State.ban_user(state, user_id)}
  end

  def handle_call({:unban_user, user_id}, _, state) do
    {:reply, :ok, State.unban_user(state, user_id)}
  end

  def handle_call({:find_suggestion_by_moderation_msg, msg_id}, _, state) do
    {:reply, State.find_unapproved_by_moderation_message(state, msg_id), state}
  end

  def handle_call({:approve, file_id}, _, state) do
    case State.approve(state, file_id) do
      :not_found -> {:reply, :not_found, state}
      {:ok, state} -> {:reply, :ok, state}
    end
  end

  def handle_call(:approved_queue, _, state) do
    {:reply, state.approved_queue, state}
  end

  def handle_call({:reject, file_id}, _, state) do
    case State.reject(state, file_id) do
      :not_found -> {:reply, :not_found, state}
      {:ok, state} -> {:reply, :ok, state}
    end
  end

  def handle_call({:find_suggestion_by_file_id, file_id}, _, state) do
    {
      :reply,
      case Map.get(state.unapproved, file_id) do
        nil -> :not_found
        x -> {:ok, x}
      end,
      state
    }
  end

  def handle_call(:get_state, _, state) do
    {:reply, state, state}
  end

  def handle_call({:put_state, new_state}, _, _) do
    {:reply, :ok, new_state}
  end

  def handle_call(:get_posting, _, state) do
    {:reply, state.posting, state}
  end

  def handle_call({:set_posting, value}, _, state) do
    {:reply, :ok, %State{state | posting: value}}
  end

  def handle_call(:get_mod_chat_state, _, state) do
    {:reply, state.mod_chat_state, state}
  end

  def handle_call({:set_mod_chat_state, value}, _, state) do
    {:reply, :ok, %State{state | mod_chat_state: value}}
  end

  # Client API

  def update_user_meta(pers, data) do
    GenServer.call(pers, {:update_user_meta, data})
  end

  @spec get_user_meta(atom | pid | {atom, any} | {:via, atom, any}, any) :: any
  def get_user_meta(pers, id) do
    GenServer.call(pers, {:get_user_meta, id})
  end

  def add_new_suggestion(
        pers,
        %{user_id: _, type: _, file_id: _} = data
      ) do
    GenServer.call(pers, {:new_suggestion, data})
  end

  def bind_moderation_msg_to_suggestion(
        pers,
        file_id,
        message_id
      ) do
    GenServer.call(pers, {:bind_mod_msg, file_id, message_id})
  end

  def find_suggestion_by_moderation_msg(pers, msg_id) do
    GenServer.call(pers, {:find_suggestion_by_moderation_msg, msg_id})
  end

  def find_existing_unapproved_suggestion_by_file_id(pers, file_id) do
    GenServer.call(pers, {:find_suggestion_by_file_id, file_id})
  end

  def approve_media(pers, file_id) do
    GenServer.call(pers, {:approve, file_id})
  end

  def reject_media(pers, file_id) do
    GenServer.call(pers, {:reject, file_id})
  end

  def get_approved_queue(pers) do
    GenServer.call(pers, :approved_queue)
  end

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

  def get_state(pers) do
    GenServer.call(pers, :get_state)
  end

  def put_state(pers, state) do
    GenServer.call(pers, {:put_state, state})
  end

  def get_posting(pers) do
    GenServer.call(pers, :get_posting)
  end

  def set_posting(pers, %CuteFemBot.Core.Posting{} = value) do
    GenServer.call(pers, {:set_posting, value})
  end

  def get_moderation_chat_state(pers) do
    GenServer.call(pers, :get_mod_chat_state)
  end

  def set_moderation_chat_state(pers, state) do
    GenServer.call(pers, {:set_mod_chat_state, state})
  end
end
