defmodule CuteFemBot.Repo.Migrations.InitTables do
  use Ecto.Migration

  # TODO timestamps

  def change do
    create table(:people) do
      add :meta, :binary
      add :banned, :boolean, null: false, default: false
    end

    create table(:chat_states, primary_key: false) do
      add :key, :string, primary_key: true
      add :data, :binary
    end

    create table(:suggestions, primary_key: false) do
      add :file_id, :string, primary_key: true
      add :file_type, :string, size: 15, null: false # document | photo | video
      add :suggestor_id, :id, null: false
      add :decision, :string, size: 4 # sfw | nsfw | not_set
      add :decision_msg_id, :id
      add :published, :boolean, null: false, default: false
    end

    create table(:schedule, primary_key: false) do
      add :data, :binary
    end
  end
end
