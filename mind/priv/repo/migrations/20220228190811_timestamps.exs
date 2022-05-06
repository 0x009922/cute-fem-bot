defmodule CuteFemBot.Repo.Migrations.Timestamps do
  use Ecto.Migration

  def change do
    alter table(:suggestions) do
      timestamps(type: :utc_datetime)
    end
  end
end
