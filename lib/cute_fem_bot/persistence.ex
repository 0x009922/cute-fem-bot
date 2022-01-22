defmodule CuteFemBot.Persistence do
  alias CuteFemBot.Persistence, as: Self
  alias CuteFemBot.Core.Suggestion
  alias CuteFemBot.Core.Schedule

  # defguard is_allowed_category(value) when Schedule.Complex.is_allowed_category(value)
  defguard is_allowed_category(value) when value in [:sfw, :nsfw]

  use TypedStruct

  typedstruct do
    # ETS/DETS
    field(:storage, any(), enforce: true)
    field(:table_users_meta, any(), enforce: true)
    field(:table_users_banned, any(), enforce: true)
    field(:table_chat_state, any(), enforce: true)
    field(:table_suggestions, any(), enforce: true)
    field(:table_queue, any(), enforce: true)
    field(:table_schedule, any(), enforce: true)
  end

  def init_ets() do
    %Self{
      storage: :ets,
      table_users_meta: :ets.new(:users_meta, [:set, :public]),
      table_users_banned: :ets.new(:users_banned, [:set, :public]),
      table_chat_state: :ets.new(:chat_state, [:set, :public]),
      table_suggestions: :ets.new(:suggestions, [:set, :public]),
      table_queue: :ets.new(:queue, [:bag, :public]),
      table_schedule: :ets.new(:schedule, [:set, :public])
    }
  end

  defp call_ets(%Self{storage: storage}, fun, args) do
    apply(storage, fun, args)
  end

  @spec update_user_meta(CuteFemBot.Persistence.t(), map) :: :ok
  def update_user_meta(%Self{} = self, %{"id" => id} = data) do
    true = call_ets(self, :insert, [self.table_users_meta, {id, data}])
    :ok
  end

  @spec get_user_meta(Self.t(), any) :: :not_found | {:ok, any}
  def get_user_meta(%Self{} = self, id) do
    case call_ets(self, :lookup, [self.table_users_meta, id]) do
      [] -> :not_found
      [{_, data}] -> {:ok, data}
    end
  end

  @spec get_ban_list(CuteFemBot.Persistence.t()) :: MapSet.t()
  def get_ban_list(%Self{} = self) do
    call_ets(self, :match, [self.table_users_banned, :"$1"])
    |> Stream.map(fn [{id}] -> id end)
    |> Enum.into(MapSet.new())
  end

  @spec ban_user(Self.t(), any) :: :ok
  def ban_user(%Self{} = self, id) do
    true = call_ets(self, :insert, [self.table_users_banned, {id}])
    :ok
  end

  def unban_user(%Self{} = self, id) do
    true = call_ets(self, :delete, [self.table_users_banned, id])
    :ok
  end

  def add_new_suggestion(
        %Self{} = self,
        %Suggestion{} = data
      ) do
    if insert_suggestion(self, data, true) do
      :ok
    else
      :duplication
    end
  end

  def bind_moderation_msg_to_suggestion(
        %Self{} = self,
        file_id,
        message_id
      ) do
    with {:ok, {_, _, suggestion}} <- lookup_suggestion_by_file_id(self, file_id) do
      suggestion = Suggestion.bind_moderation_msg(suggestion, message_id)
      true = insert_suggestion(self, suggestion)
      :ok
    end
  end

  defp insert_suggestion(
         %Self{} = self,
         %Suggestion{} = data,
         is_new \\ false
       ) do
    method = if is_new, do: :insert_new, else: :insert

    # later bind it to something else, not to file_id,
    # because later there will be media groups
    call_ets(self, method, [
      self.table_suggestions,
      {data.file_id, data.moderation_message_id, data}
    ])
  end

  defp lookup_suggestion_by_file_id(%Self{} = self, file_id) do
    case call_ets(self, :lookup, [self.table_suggestions, file_id]) do
      [] -> :not_found
      [data] -> {:ok, data}
    end
  end

  @spec find_suggestion_by_moderation_msg(Self.t(), any) :: :not_found | {:ok, Suggestion.t()}
  def find_suggestion_by_moderation_msg(%Self{} = self, msg_id) do
    case call_ets(self, :match, [self.table_suggestions, {:_, msg_id, :"$1"}]) do
      [[%Suggestion{} = data]] -> {:ok, data}
      [] -> :not_found
    end
  end

  @spec find_existing_unapproved_suggestion_by_file_id(Self.t(), any()) ::
          :not_found | {:ok, Suggestion.t()}
  def find_existing_unapproved_suggestion_by_file_id(%Self{} = self, file_id) do
    lookup_suggestion_by_file_id(self, file_id)
  end

  @spec approve_media(Self.t(), any(), :nsfw | :sfw) :: :not_found | :ok
  def approve_media(%Self{} = self, file_id, category \\ :sfw)
      when is_allowed_category(category) do
    with {:ok, {_, _, suggestion}} <- lookup_suggestion_by_file_id(self, file_id) do
      # deleting from suggestions
      true = delete_suggestion(self, file_id)

      # appending to queue
      true =
        call_ets(self, :insert, [self.table_queue, {category, suggestion.file_id, suggestion}])

      :ok
    end
  end

  @spec reject_media(Self.t(), any()) :: :ok
  def reject_media(%Self{} = self, file_id) do
    true = delete_suggestion(self, file_id)
    :ok
  end

  defp delete_suggestion(%Self{} = self, file_id) do
    call_ets(self, :delete, [self.table_suggestions, file_id])
  end

  def get_approved_queue(%Self{} = self, category) when is_allowed_category(category) do
    case call_ets(self, :lookup, [self.table_queue, category]) do
      [] -> []
      items -> Enum.map(items, fn {_, _, x} -> x end)
    end
  end

  def cancel_approved(%Self{} = self, file_id) do
    true = call_ets(self, :match_delete, [self.table_queue, {:_, file_id, :_}])
    :ok
  end

  def commit_as_flushed(%Self{} = self, files) when is_list(files) do
    Enum.each(files, &cancel_approved(self, &1))
    :ok
  end

  def get_schedule(%Self{} = self) do
    case call_ets(self, :lookup, [self.table_schedule, :schedule]) do
      [%Schedule.Complex{} = value] -> value
      [] -> nil
    end
  end

  def set_schedule(%Self{} = self, %Schedule.Complex{} = value) do
    true = call_ets(self, :insert, [self.table_schedule, {:schedule, value}])
    :ok
  end

  def get_chat_state(%Self{} = self, key) do
    case call_ets(self, :lookup, [self.table_chat_state, key]) do
      [] -> nil
      [{_, state}] -> state
    end
  end

  def set_chat_state(%Self{} = self, key, state) do
    true = call_ets(self, :insert, [self.table_chat_state, {key, state}])
    :ok
  end
end
