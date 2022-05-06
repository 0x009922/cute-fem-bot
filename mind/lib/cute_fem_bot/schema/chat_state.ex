defmodule CuteFemBot.Schema.ChatState do
  use Ecto.Schema

  @primary_key false
  schema "chat_states" do
    field(:key, :string, primary_key: true)
    field(:data, :binary)
  end
end
