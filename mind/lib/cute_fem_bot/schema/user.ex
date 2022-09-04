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

  def decode_meta(user) do
    :erlang.binary_to_term(user.meta)
  end
end

defimpl Jason.Encoder, for: CuteFemBot.Schema.User do
  def encode(%CuteFemBot.Schema.User{} = user, opts) do
    Jason.Encode.map(
      %{
        id: user.id,
        banned: user.banned,
        meta: user |> CuteFemBot.Schema.User.decode_meta()
      },
      opts
    )
  end
end
