defmodule CuteFemBot.Schema.Suggestion do
  use Ecto.Schema
  import Ecto.Changeset
  alias CuteFemBot.Schema.Suggestion, as: Self

  @type decision() :: :sfw | :nsfw | :reject
  @type file_type() :: :photo | :document | :video

  @allowed_decisions ~w(sfw nsfw reject)a
  @allowed_file_types ~w(photo video document)a

  @doc """
  - `file_mime_type` - not always available
  """
  @primary_key false
  @timestamps_opts type: :utc_datetime
  @derive {
    Jason.Encoder,
    only: [
      :file_id,
      :made_by,
      :file_type,
      :file_mime_type,
      :decision,
      :decision_msg_id,
      :decision_made_by,
      :decision_made_at,
      :published,
      :inserted_at,
      :updated_at
    ]
  }
  schema "suggestions" do
    timestamps()
    field(:file_id, :string, primary_key: true)

    field(:file_type, Ecto.Enum, values: @allowed_file_types)
    field(:file_mime_type, :string, default: nil)
    field(:made_by, :id, default: nil)

    field(:decision, Ecto.Enum, values: @allowed_decisions, default: nil)
    field(:decision_msg_id, :id, default: nil)
    field(:decision_made_by, :id, default: nil)
    field(:decision_made_at, :utc_datetime, default: nil)

    field(:published, :boolean, default: false)
  end

  # @spec new(file_type(), binary(), integer()) :: Self()
  def new(type, file_id, made_by)
      when type in @allowed_file_types and is_binary(file_id) and is_integer(made_by) do
    %Self{
      file_id: file_id,
      file_type: type,
      made_by: made_by
    }
  end

  @doc """
  Parses Telegram message and extracts suggestions of different types from it
  """
  def extract_from_message(msg) do
    %{"from" => %{"id" => user_id}} = msg

    result =
      case msg do
        %{"photo" => sizes} ->
          %{"file_id" => file_id} = Enum.max_by(sizes, &Map.fetch!(&1, "file_size"))
          {:photo, file_id, nil}

        %{"video" => %{"file_id" => file_id, "mime_type" => mime}} ->
          {:video, file_id, mime}

        %{"document" => %{"file_id" => file_id, "mime_type" => mime}} ->
          if mime =~ ~r{^(image|video)\/} do
            {:document, file_id, mime}
          else
            :none
          end

        _ ->
          :none
      end

    case result do
      :none ->
        :none

      {type, file_id, mime} ->
        {
          :ok,
          %Self{
            file_type: type,
            file_mime_type: mime,
            file_id: file_id,
            made_by: user_id
          }
        }
    end
  end

  def to_telegram_send(%Self{file_type: ty, file_id: id}) do
    ty_str = Atom.to_string(ty)

    %{
      method_name: "send" <> String.capitalize(ty_str),
      body_part: Map.put(%{}, ty_str, id)
    }
  end

  def make_decision(%Self{} = self, decision, made_at, made_by)
      when decision in @allowed_decisions do
    self
    |> change(%{
      decision: decision,
      decision_made_at: made_at |> DateTime.truncate(:second),
      decision_made_by: made_by,
      decision_msg_id: nil
    })
  end

  def reset_decision(%Self{} = self) do
    self
    |> change(
      decision: nil,
      decision_made_at: nil,
      decision_made_by: nil,
      decision_msg_id: nil
    )
  end

  def update_decision_message(%Self{} = self, id) when is_integer(id) do
    self
    |> change(decision_msg_id: id)
  end

  def published(self) do
    self |> change(published: true)
  end
end
