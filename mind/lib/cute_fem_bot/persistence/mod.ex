defmodule CuteFemBot.Persistence do
  alias CuteFemBot.Core.Schedule
  alias CuteFemBot.Repo
  alias CuteFemBot.Schema
  alias Schema.Suggestion
  alias CuteFemBot.Persistence.IndexSuggestionsParams
  alias CuteFemBot.Core.Pagination.Params, as: PaginationParams
  alias CuteFemBot.Core.Pagination.Resolved, as: PaginationResolved
  import Ecto.Query

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
    data
    |> Repo.insert!()

    :ok
  end

  def bind_moderation_msg_to_suggestion(
        file_id,
        message_id
      ) do
    Repo.one!(
      from(s in Schema.Suggestion,
        where: s.file_id == ^file_id
      )
    )
    |> Schema.Suggestion.update_decision_message(message_id)
    |> Repo.update!()

    :ok
  end

  @spec find_suggestion_by_moderation_msg(any) :: :not_found | {:ok, Schema.Suggestion.t()}
  def find_suggestion_by_moderation_msg(msg_id) when not is_nil(msg_id) do
    case Repo.one(from(s in Schema.Suggestion, where: s.decision_msg_id == ^msg_id)) do
      nil -> :not_found
      item -> {:ok, item}
    end
  end

  @spec find_existing_unapproved_suggestion_by_file_id(any()) ::
          :not_found | {:ok, Suggestion.t()}
  def find_existing_unapproved_suggestion_by_file_id(file_id) do
    case Repo.one(
           from(s in Schema.Suggestion,
             where: s.file_id == ^file_id and is_nil(s.decision)
           )
         ) do
      nil -> :not_found
      item -> {:ok, item}
    end
  end

  @spec make_decision(binary(), integer(), DateTime.t(), :nsfw | :sfw | :reject) ::
          {:error, :not_found | :published} | :ok
  def make_decision(file_id, made_by, made_at, decision) do
    case Repo.one(from(s in Schema.Suggestion, where: s.file_id == ^file_id)) do
      nil ->
        {:error, :not_found}

      %Schema.Suggestion{published: true} ->
        {:error, :published}

      item ->
        Schema.Suggestion.make_decision(item, decision, made_at, made_by)
        |> Repo.update!()

        :ok
    end
  end

  def cancel_decision(file_id) do
    Repo.one!(from(s in Schema.Suggestion, where: s.file_id == ^file_id))
    |> Schema.Suggestion.reset_decision()
    |> Repo.update!()

    :ok
  end

  def get_approved_queue(category) when category in ~w(sfw nsfw)a do
    Repo.all(
      from(s in Schema.Suggestion,
        where: s.decision == ^category and not s.published,
        order_by: [asc: s.decision_made_at]
      )
    )
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

      %Schema.Schedule{data: raw} ->
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

  @doc """
  Indexing suggestions & their users by given params.

  Returned users is that either **made a suggestion** or **made a decision**.
  """
  def index_suggestions(%IndexSuggestionsParams{} = params) do
    query_with_only_where =
      from(s in Schema.Suggestion)
      |> IndexSuggestionsParams.apply_query_where(params)

    query =
      from(s in query_with_only_where,
        order_by: [desc: s.inserted_at]
      )
      |> IndexSuggestionsParams.apply_query_order(params)
      |> IndexSuggestionsParams.apply_query_pagination(params)

    {suggestions, users} =
      from(s in query,
        left_join: u in Schema.User,
        on: s.decision_made_by == u.id or s.made_by == u.id,
        distinct: true,
        select: {s, u}
      )
      |> Repo.all()
      |> Enum.unzip()

    # users may be nil & duplicated
    users =
      users
      |> Stream.reject(&is_nil/1)
      |> Stream.uniq_by(& &1.id)
      |> Enum.into([])

    # suggestions may be duplicated because of "OR" join
    suggestions = suggestions |> Stream.uniq_by(& &1.file_id) |> Enum.into([])

    suggestions_count = from(s in query_with_only_where, select: count(s.file_id)) |> Repo.one!()

    %{
      pagination: params.pagination |> PaginationResolved.from_params(suggestions_count),
      suggestions: suggestions,
      users: users
    }
  end
end
