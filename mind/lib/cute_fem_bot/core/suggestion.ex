defmodule CuteFemBot.Core.Suggestion do
  use TypedStruct
  @allowed_types [:photo, :video, :document]

  typedstruct do
    field(:type, :photo | :video | :document, enforce: true)
    field(:mime_type, String.t(), default: nil)
    field(:file_id, String.t(), enforce: true)
    field(:user_id, String.t(), enforce: true)
    field(:decision_msg_id, any(), default: nil)
  end

  alias __MODULE__, as: Self

  def new(type, file_id, user_id) when type in @allowed_types do
    %Self{
      type: type,
      file_id: file_id,
      user_id: user_id
    }
  end

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
            type: type,
            file_id: file_id,
            user_id: user_id,
            mime_type: mime
          }
        }
    end
  end

  def to_send(%Self{type: ty, file_id: id}) do
    ty_str = Atom.to_string(ty)

    %{
      method_name: "send" <> String.capitalize(ty_str),
      body_part: Map.put(%{}, ty_str, id)
    }
  end

  def bind_decision_message(%Self{} = self, msg_id) do
    %Self{self | decision_msg_id: msg_id}
  end
end
