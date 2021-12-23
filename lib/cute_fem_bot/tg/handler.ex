defmodule CuteFemBot.Tg.Handler do
  require Logger

  alias CuteFemBot.Tg.Types

  def handle(updates) do
    Task.async_stream(updates, fn x ->
      case x do
        # %Types.Update{message: msg} ->
        #   %Types.Message{from: %{"id" => chat_id}} = msg

        #   case msg do
        #     %Types.Message{photo: photo} when not is_nil(photo) ->
        #       IO.inspect(photo)

        #       file_id =
        #         Stream.map(photo, fn %{"file_id" => x} -> x end)
        #         |> Stream.take(1)
        #         |> Enum.fetch!(0)

        #       CuteFemBot.Tg.Api.Server.send_photo(%Types.SendPhotoParams{
        #         chat_id: chat_id,
        #         file_id: file_id
        #       })

        #     %Types.Message{
        #       document: %{
        #         "file_id" => file_id,
        #         "mime_type" => mime
        #       }
        #     } ->
        #       Logger.info("Doc received #{mime}")

        #       if String.starts_with?(mime, "image/") do
        #         CuteFemBot.Tg.Api.Server.send_photo(%Types.SendPhotoParams{
        #           chat_id: chat_id,
        #           file_id: file_id
        #         })
        #       end

        #     _ ->
        #       nil
        #   end

        _ ->
          nil
      end
    end)
    |> Enum.to_list()
  end
end
