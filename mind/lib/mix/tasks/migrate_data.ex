defmodule Mix.Tasks.MigrateData do
  @state_path "data/persistence_old_state.bin"

  use Mix.Task
  alias CuteFemBot.Schema
  alias CuteFemBot.Repo
  require Logger

  @impl Mix.Task
  def run(_) do
    %{
      users_meta: users_meta,
      admin_states: _admin_states,
      approved_queue: approved,
      banned: banned,
      posting: _posting,
      unapproved: unapproved
    } = read_state() |> :erlang.binary_to_term()

    start_repo()

    migrate_users_meta(users_meta, banned)
    migrate_unapproved(unapproved)
    migrate_approved(approved)

    Logger.info("Data is migrated!")
  end

  defp read_state() do
    File.read!(@state_path)
  end

  defp start_repo() do
    {:ok, _} = Application.ensure_all_started(:ecto_sqlite3)
    {:ok, _} = Repo.start_link()
  end

  defp migrate_users_meta(map, banned) do
    mapped =
      Map.to_list(map)
      |> Enum.map(fn {id, meta} ->
        %{
          id: id,
          meta: :erlang.term_to_binary(meta),
          banned: MapSet.member?(banned, id)
        }
      end)

    Repo.insert_all(Schema.User, mapped)
  end

  defp migrate_unapproved(items) do
    mapped =
      items
      |> Map.values()
      |> Enum.map(fn %{file_id: fid, moderation_message_id: msg_id, type: type, user_id: uid} ->
        %{
          file_id: fid,
          file_type: Atom.to_string(type),
          suggestor_id: uid,
          decision_msg_id: msg_id,
          decision: nil,
          published: false
        }
      end)

    Repo.insert_all(Schema.Suggestion, mapped)
  end

  defp migrate_approved(items) do
    mapped =
      items
      |> Enum.map(fn %{file_id: fid, type: type, user_id: uid} ->
        %{
          file_id: fid,
          file_type: Atom.to_string(type),
          suggestor_id: uid,
          decision_msg_id: nil,
          decision: "sfw",
          published: false
        }
      end)

    Repo.insert_all(Schema.Suggestion, mapped)
  end
end
