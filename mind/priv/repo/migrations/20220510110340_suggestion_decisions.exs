defmodule CuteFemBot.Repo.Migrations.SuggestionDecisions do
  use Ecto.Migration

  def change do
    create table("suggestions_new", primary_key: false) do
      timestamps(type: :utc_datetime)
      add(:file_id, :string, primary_key: true)
      add(:file_type, :string, null: false)
      add(:file_mime_type, :string)
      add(:made_by, :id, null: false)
      add(:decision, :string)
      add(:decision_msg_id, :id)
      add(:decision_made_by, :id)
      add(:decision_made_at, :utc_datetime)
      add(:published, :boolean, default: false)
    end

    execute("""
      insert into suggestions_new
      (
        file_id,
        inserted_at,
        updated_at,
        file_type,
        file_mime_type,
        made_by,
        decision,
        decision_msg_id,
        published
      )
      select
        file_id,
        coalesce(inserted_at, strftime('%Y-%m-%dT%H-%M-%S','now')),
        updated_at,
        file_type,
        file_mime_type,
        suggestor_id,
        decision,
        decision_msg_id,
        published
      from suggestions
    """)

    drop(table("suggestions"))

    # renaming of "suggestions_new" -> "suggestions" is done in a separate migration
  end
end
