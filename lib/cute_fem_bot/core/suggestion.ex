defmodule CuteFemBot.Core.Suggestion do
  use TypedStruct
  @allowed_types [:photo, :video, :document]

  typedstruct do
    field(:type, :photo | :video | :document, enforce: true)
    field(:file_id, String.t(), enforce: true)
    field(:user_id, String.t(), enforce: true)
    field(:moderation_message_id, any(), default: nil)
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
        %{"photo" => [%{"file_id" => file_id} | _]} ->
          {:photo, file_id}

        %{"video" => %{"file_id" => file_id}} ->
          {:video, file_id}

        %{"document" => %{"file_id" => file_id, "mime_type" => mime}} ->
          if mime =~ ~r{^(image|video)\/} do
            {:document, file_id}
          else
            :none
          end

        _ ->
          :none
      end

    case result do
      :none -> :none
      {type, file_id} -> {:ok, %Self{type: type, file_id: file_id, user_id: user_id}}
    end
  end

  def to_send(%Self{type: ty, file_id: id}) do
    ty_str = Atom.to_string(ty)

    %{
      method_name: "send" <> String.capitalize(ty_str),
      body_part: Map.put(%{}, ty_str, id)
    }
  end

  def bind_moderation_msg(%Self{} = self, msg_id) do
    %Self{self | moderation_message_id: msg_id}
  end
end
