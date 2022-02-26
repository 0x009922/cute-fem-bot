defmodule CuteFemBot.Repo.Migrations.AddMimeType do
  use Ecto.Migration

  def change do
    alter table(:suggestions) do
      add :file_mime_type, :string
    end
  end
end
