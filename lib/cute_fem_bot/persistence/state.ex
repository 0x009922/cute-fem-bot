defmodule CuteFemBot.Persistence.State do
  use TypedStruct

  alias __MODULE__, as: Self
  alias CuteFemBot.Core.Suggestion

  typedstruct do
    field(:users_meta, map(), default: %{})
    field(:unapproved, map(), default: %{})
    field(:approved_queue, map(), default: %{sfw: [], nsfw: []})
    field(:banned, MapSet.t(), default: MapSet.new())
    field(:schedule, CuteFemBot.Core.Schedule.Complex.t(), default: nil)
    field(:admin_states, any(), default: %{})
  end

  def update_user_meta(%Self{users_meta: x} = state, %{"id" => id} = data) do
    %Self{state | users_meta: Map.put(x, id, data)}
  end

  def add_suggestion(
        %Self{unapproved: unapproved} = state,
        %Suggestion{file_id: file_id} = suggestion
      ) do
    if Map.has_key?(unapproved, file_id) do
      {:duplication, state}
    else
      {
        :ok,
        %Self{state | unapproved: Map.put(unapproved, file_id, suggestion)}
      }
    end
  end

  def bind_moderation_message_to_suggestion(state, msg_id, file_id) do
    if not Map.has_key?(state.unapproved, file_id) do
      {:not_found, state}
    else
      {
        :ok,
        Map.update!(state, :unapproved, fn map ->
          Map.update!(map, file_id, fn %Suggestion{} = item ->
            Suggestion.bind_moderation_msg(item, msg_id)
          end)
        end)
      }
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

  def approve(state, file_id, category) when category in [:sfw, :nsfw] do
    case Map.pop(state.unapproved, file_id) do
      {nil, _} ->
        {:not_found, state}

      {data, unapproved} ->
        {
          :ok,
          %Self{
            state
            | unapproved: unapproved,
              approved_queue:
                Map.update!(state.approved_queue, category, fn list -> list ++ [data] end)
          }
        }
    end
  end

  def reject(state, file_id) do
    case Map.pop(state.unapproved, file_id) do
      {nil, _} ->
        {:not_found, state}

      {_, unapproved} ->
        {:ok, %Self{state | unapproved: unapproved}}
    end
  end

  def files_posted(state, ids) do
    %Self{
      state
      | approved_queue:
          Enum.map(state.approved_queue, fn {category, queue} ->
            queue =
              Enum.filter(queue, fn %Suggestion{file_id: file_id} ->
                file_id not in ids
              end)

            {category, queue}
          end)
          |> Enum.into(%{})
    }
  end

  def get_admin_chat_state(%Self{} = self, id) do
    Map.get(self.admin_states, id)
  end

  def set_admin_chat_state(%Self{} = self, id, state) do
    %Self{self | admin_states: Map.put(self.admin_states, id, state)}
  end

  def cancel_approved(%Self{} = self, file_id) do
    # identical to "posted" behavior
    files_posted(self, [file_id])
  end
end
