defmodule CuteFemBot.Logic.Handler.Middleware.Message do
  alias CuteFemBot.Telegram.Api
  alias CuteFemBot.Persistence

  def main() do
    [
      :find_message_sender,
      :update_user_meta,
      :moderation_or_suggestor
    ]
  end

  def find_message_sender(%{update: update} = ctx) do
    case update do
      %{"message" => %{"from" => %{"id" => user_id} = user, "chat" => %{"id" => chat_id}}} ->
        {
          :cont,
          ctx: Map.put(ctx, :message_sender, %{user: user, user_id: user_id, chat_id: chat_id})
        }

      _ ->
        :cont
    end
  end

  def update_user_meta(%{persistence: persistence, message_sender: %{user: user}}) do
    CuteFemBot.Persistence.update_user_meta(persistence, user)
    :cont
  end

  def moderation_or_suggestor(
        %{
          message_sender: %{chat_id: cid},
          config: %{moderation_chat_id: moderation_chat_id}
        } = ctx
      ) do
    branch =
      if cid == moderation_chat_id do
        # moderation
        [
          :empty_moderation_answer
        ]
      else
        # suggestor
        [
          :fetch_ban_list,
          :ignore_user_if_he_is_banned,
          :greet_user_if_start_command,
          :find_any_media,
          :handle_media
        ]
      end

    {:cont, :sub_branch, branch, ctx}
  end

  def empty_moderation_answer(%{api: api, config: %{moderation_chat_id: chat_id}}) do
    Api.send_message(api, %{
      "chat_id" => chat_id,
      "text" => "Я не знаю, зачем вы мне прислали сообщение"
    })

    :halt
  end

  def greet_user_if_start_command(%{update: update} = ctx) do
    case update do
      %{"message" => %{"text" => "/start"}} ->
        %{message_sender: %{user_id: uid}, telegram_api: api} = ctx

        CuteFemBot.Telegram.Api.request(
          api,
          method_name: "sendMessage",
          body: %{
            "chat_id" => uid,
            "text" => "Hello!"
          }
        )

        :halt

      _ ->
        :cont
    end
  end

  def fetch_ban_list(%{persistence: pers} = ctx) do
    {:cont, Map.put(ctx, :banned_users, Persistence.get_ban_list(pers))}
  end

  def ignore_user_if_he_is_banned(%{
        message_sender: %{user_id: uid},
        banned_users: banned_list,
        api: api
      }) do
    if uid in banned_list do
      Api.send_message(api, %{"chat_id" => uid, "text" => "ты в бане"})
      :halt
    else
      :cont
    end
  end

  def find_any_media(%{update: %{"message" => msg}} = ctx) do
    media =
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

    case media do
      :none -> :cont
      some -> {:cont, Map.put(ctx, :message_media, some)}
    end
  end

  def handle_media(
        %{
          update: update,
          telegram_api: api,
          persistence: pers,
          message_sender: %{user_id: uid},
          config: %{moderation_chat_id: moder_chat_id}
        } = ctx
      ) do
    %{"message" => %{"message_id" => message_id}} = update

    case ctx do
      %{:message_media => {type, file_id} = media} ->
        Api.send_message(api, %{
          "chat_id" => uid,
          "text" => "Спасибочки, принял )",
          "reply_to_message_id" => message_id
        })

        %{"message_id" => moderation_message_id} =
          Api.send_message(
            api,
            %{
              "chat_id" => moder_chat_id,
              "text" => "Новое предложение от пользователя (#{uid})[tg://user?id=#{uid}]",
              "parse_mode" => "markdown",
              "reply_markup" => %{
                "inline_keyboard" => [
                  [
                    %{"text" => "+", "data" => "approve"},
                    %{"text" => "-", "data" => "reject"},
                    %{"text" => "ban", "data" => "ban"}
                  ]
                ]
              }
            }
            |> Map.put(Atom.to_string(type), file_id)
          )

        Persistence.add_new_suggestion(pers, media, moderation_message_id)

        :halt

      _ ->
        Api.send_message(api, %{
          "chat_id" => uid,
          "text" => "Не-не-не... мне нужны только фотки",
          "reply_to_message_id" => message_id
        })

        :halt
    end
  end
end
