defmodule CuteFemBot.Schema.Suggestion do
  use Ecto.Schema
  import Ecto.Changeset
  alias CuteFemBot.Schema.Suggestion, as: Self

  @primary_key false
  schema "suggestions" do
    field(:file_id, :string, primary_key: true)
    field(:file_type, :string)
    field(:suggestor_id, :id)
    field(:decision, :string, default: nil)
    field(:decision_msg_id, :id, default: nil)
    field(:published, :boolean, default: false)
  end

  def from_core(%CuteFemBot.Core.Suggestion{} = data) do
    %Self{
      file_id: data.file_id,
      file_type: Atom.to_string(data.type),
      decision_msg_id: data.decision_msg_id,
      suggestor_id: data.user_id
    }
  end

  def to_core(%Self{} = self) do
    %CuteFemBot.Core.Suggestion{
      file_id: self.file_id,
      type: String.to_existing_atom(self.file_type),
      user_id: self.suggestor_id,
      decision_msg_id: self.decision_msg_id
    }
  end

  def make_decision(%Self{} = self, decision) when decision in ["sfw", "nsfw", "reject"] do
    self
    |> change(%{decision: decision, decision_msg_id: nil})
  end

  def clear_decision(%Self{} = self) do
    self
    |> change(%{decision: nil})
  end

  def bind_decision_msg_id(self, id) do
    self
    |> change(decision_msg_id: id)
  end

  def published(self) do
    self |> change(published: true)
  end
end
