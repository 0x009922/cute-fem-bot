defmodule CuteFemBot.Schema.Schedule do
  use Ecto.Schema

  @primary_key false
  schema "schedule" do
    field(:data, :binary)
  end
end
