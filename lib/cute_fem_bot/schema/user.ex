defmodule CuteFemBot.Schema.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "people" do
    field(:meta, :binary)
    field(:banned, :boolean, default: false)
  end

  def update_meta(user, meta) when is_binary(meta) do
    user
    |> change(meta: meta)
  end

  def update_banned(user, flag) when is_boolean(flag) do
    user
    |> change(banned: flag)
  end
end
