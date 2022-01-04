defmodule CuteFemBot.Persistence.State do
  use TypedStruct

  alias __MODULE__, as: Self
  alias CuteFemBot.Core.Suggestion

  typedstruct do
    field(:users_meta, map(), default: %{})
    field(:unapproved, map(), default: %{})
    field(:approved_queue, list(), default: [])
    field(:banned, MapSet.t(), default: MapSet.new())
    field(:posting, CuteFemBot.Core.Posting.t(), default: nil)
    field(:mod_chat_state, any(), default: nil)
  end

  def update_user_meta(%Self{users_meta: x} = state, %{"id" => id} = data) do
    %Self{state | users_meta: Map.put(x, id, data)}
  end

  def add_suggestion(
        %Self{unapproved: unapproved} = state,
        %Suggestion{file_id: file_id} = suggestion
      ) do
    if Map.has_key?(unapproved, file_id) do
      :duplication
    else
      {
        :ok,
        %Self{state | unapproved: Map.put(unapproved, file_id, suggestion)}
      }
    end
  end

  def bind_moderation_message_to_suggestion(state, msg_id, file_id) do
    if not Map.has_key?(state.unapproved, file_id) do
      :not_found
    else
      Map.update!(state, :unapproved, fn map ->
        Map.update!(map, file_id, fn %Suggestion{} = item ->
          Suggestion.bind_moderation_msg(item, msg_id)
        end)
      end)
    end
  end

  def get_user_meta(%Self{users_meta: data}, user_id) do
    case data do
      %{^user_id => x} -> {:ok, x}
      _ -> :not_found
    end
  end

  def ban_user(%Self{banned: banned} = state, user_id) do
    %Self{state | banned: MapSet.put(banned, user_id)}
  end

  def unban_user(%Self{banned: banned} = state, user_id) do
    %Self{state | banned: MapSet.delete(banned, user_id)}
  end

  def find_unapproved_by_moderation_message(state, msg_id) do
    find_result =
      Enum.find(state.unapproved, fn {_file_id, data} ->
        case data do
          %Suggestion{moderation_message_id: ^msg_id} -> true
          _ -> false
        end
      end)

    case find_result do
      nil ->
        :not_found

      {_, data} ->
        {:ok, data}
    end
  end

  def approve(state, file_id) do
    case Map.pop(state.unapproved, file_id) do
      {nil, _} ->
        :not_found

      {data, unapproved} ->
        {
          :ok,
          %Self{
            state
            | unapproved: unapproved,
              approved_queue: state.approved_queue ++ [data]
          }
        }
    end
  end

  def reject(state, file_id) do
    case Map.pop(state.unapproved, file_id) do
      {nil, _} ->
        :not_found

      {_, unapproved} ->
        {:ok, %Self{state | unapproved: unapproved}}
    end
  end

  def files_posted(state, ids) do
    %Self{
      state
      | approved_queue:
          Enum.filter(state.approved_queue, fn %Suggestion{file_id: file_id} ->
            file_id not in ids
          end)
    }
  end
end
