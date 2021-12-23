defmodule CuteFemBot.Core.UpdatesHandler do
  alias CuteFemBot.Tg.Types
  alias CuteFemBot.Config
  alias __MODULE__.Input
  alias __MODULE__.Output

  def handle(%Input{} = input) do
    %Output{actions: []}
  end

  defp handle_update(
         moderation_chat_id: mod_id,
         banned_list: banned,
         update: %Types.Update{value: update}
       ) do
    case update do
      {:message, msg} ->
        case msg do
          %Types.Message{chat: %{"id" => ^mod_id}} ->
            # message in moderation chat
            :noop

          # common user message, maybe a proposal
          %Types.Message{from: %{"id" => sender_id}} ->
            # check if sender is banned
            if sender_id in banned do
              {:reply_user_is_banned, sender_id}
            else
              # not banned, checking for images in the message
              case msg do
                %Types.Message{photo: photo} when is_list(photo) and length(photo) > 0 ->
                  :noop

                _ ->
                  # no photos :<
                  {:reply_user_should_send_pictures, sender_id}
              end
            end
        end

      _ ->
        :noop
    end
  end

  # defp try_find_photo
end
