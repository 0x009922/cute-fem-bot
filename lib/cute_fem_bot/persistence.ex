defmodule CuteFemBot.Persistence do
  alias CuteFemBot.Core.Suggestion
  alias CuteFemBot.Core.Schedule
  alias CuteFemBot.Schema
  alias CuteFemBot.Repo
  import Ecto.Query

  # defguard is_allowed_category(value) when Schedule.Complex.is_allowed_category(value)
  defguard is_allowed_category(value) when value in [:sfw, :nsfw]

  defp term_to_binary(term) do
    :erlang.term_to_binary(term)
  end

  defp binary_to_term(binary) do
    :erlang.binary_to_term(binary)
  end

  defp find_user(id) do
    case Repo.get(Schema.User, id) do
      nil -> :not_found
      found -> {:ok, found}
    end
  end

  defp find_or_init_user(id) do
    case find_user(id) do
      :not_found -> %Schema.User{id: id}
      {:ok, user} -> user
    end
  end

  @spec update_user_meta(map) :: :ok
  def update_user_meta(%{"id" => id} = meta) do
    find_or_init_user(id)
    |> Schema.User.update_meta(term_to_binary(meta))
    |> Repo.insert_or_update!()

    :ok
  end

  @spec get_user_meta(any) :: :not_found | {:ok, any}
  def get_user_meta(id) do
    with {:ok, %Schema.User{meta: raw}} <- find_user(id) do
      {:ok, binary_to_term(raw)}
    end
  end

  @spec get_ban_list() :: MapSet.t()
  def get_ban_list() do
    Repo.all(from(u in Schema.User, where: u.banned == true))
    |> Stream.map(fn %Schema.User{id: id} -> id end)
    |> Enum.into(MapSet.new())
  end

  @spec ban_user(any) :: :ok
  def ban_user(id) do
    find_or_init_user(id)
    |> Schema.User.update_banned(true)
    |> Repo.insert_or_update!()

    :ok
  end

  def unban_user(id) do
    find_or_init_user(id)
    |> Schema.User.update_banned(false)
    |> Repo.insert_or_update!()

    :ok
  end

  def add_new_suggestion(%Suggestion{} = data) do
    Schema.Suggestion.from_core(data)
    |> Repo.insert!()

    :ok
  end

  def bind_moderation_msg_to_suggestion(
        file_id,
        message_id
      ) do
    Repo.one!(from(s in Schema.Suggestion, where: s.file_id == ^file_id))
    |> Schema.Suggestion.bind_decision_msg_id(message_id)
    |> Repo.update!()

    :ok
  end

  @spec find_suggestion_by_moderation_msg(any) :: :not_found | {:ok, Suggestion.t()}
  def find_suggestion_by_moderation_msg(msg_id) do
    case Repo.one(from(s in Schema.Suggestion, where: s.decision_msg_id == ^msg_id)) do
      nil -> :not_found
      item -> {:ok, Schema.Suggestion.to_core(item)}
    end
  end

  @spec find_existing_unapproved_suggestion_by_file_id(any()) ::
          :not_found | {:ok, Suggestion.t()}
  def find_existing_unapproved_suggestion_by_file_id(file_id) do
    case Repo.one(
           from(s in Schema.Suggestion, where: s.file_id == ^file_id and is_nil(s.decision))
         ) do
      nil -> :not_found
      item -> {:ok, Schema.Suggestion.to_core(item)}
    end
  end

  @spec approve_media(any(), :nsfw | :sfw) :: :not_found | :ok
  def approve_media(file_id, category \\ :sfw)
      when is_allowed_category(category) do
    case Repo.one(from(s in Schema.Suggestion, where: s.file_id == ^file_id)) do
      nil ->
        :not_found

      item ->
        Schema.Suggestion.make_decision(item, Atom.to_string(category))
        |> Repo.update!()

        :ok
    end
  end

  @spec reject_media(any()) :: :ok
  def reject_media(file_id) do
    Repo.one!(from(s in Schema.Suggestion, where: s.file_id == ^file_id))
    |> Schema.Suggestion.make_decision("reject")
    |> Repo.update!()

    :ok
  end

  def get_approved_queue(category) when is_allowed_category(category) do
    Repo.all(
      from(s in Schema.Suggestion,
        where: s.decision == ^Atom.to_string(category) and not s.published
      )
    )
    |> Enum.map(&Schema.Suggestion.to_core/1)
  end

  def cancel_approved(file_id) do
    Repo.one!(from(s in Schema.Suggestion, where: s.file_id == ^file_id))
    |> Schema.Suggestion.clear_decision()
    |> Repo.update!()

    :ok
  end

  def check_as_published(files) when is_list(files) do
    Repo.update_all(
      from(s in Schema.Suggestion, where: s.file_id in ^files),
      set: [published: true]
    )

    :ok
  end

  def get_schedule() do
    case Schema.Schedule |> Repo.one() do
      nil ->
        nil

      raw ->
        case binary_to_term(raw) do
          %Schedule.Complex{} = x -> x
        end
    end
  end

  def set_schedule(%Schedule.Complex{} = value) do
    Schema.Schedule
    |> Repo.delete_all()

    %Schema.Schedule{data: term_to_binary(value)}
    |> Repo.insert!()

    :ok
  end

  def get_chat_state(key) do
    case Repo.one(from(cs in Schema.ChatState, where: cs.key == ^key)) do
      nil -> nil
      %Schema.ChatState{data: raw} -> binary_to_term(raw)
    end
  end

  def set_chat_state(key, state) do
    case Repo.one(from(cs in Schema.ChatState, where: cs.key == ^key)) do
      nil -> %Schema.ChatState{key: key}
      state -> state
    end
    |> Ecto.Changeset.change(data: term_to_binary(state))
    |> Repo.insert_or_update!()

    :ok
  end
end
