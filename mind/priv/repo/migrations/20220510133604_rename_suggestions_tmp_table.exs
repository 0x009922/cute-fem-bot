defmodule CuteFemBot.Repo.Migrations.RenameSuggestionsTmpTable do
  use Ecto.Migration

  @moduledoc """
  Actually it is a part of the previous migration, but due to some reason, it is impossible
  there to rename created table, because "suggestions table still exists" even after dropping
  """

  def change do
    rename(table("suggestions_new"), to: table("suggestions"))
  end
end
