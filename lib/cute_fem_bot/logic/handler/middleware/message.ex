defmodule CuteFemBot.Logic.Handler.Middleware.Message do
  alias CuteFemBot.Telegram.Api
  alias CuteFemBot.Persistence

  def schema() do
    %{
      main: [
        :find_message_sender,
        :update_user_meta,
        :moderation_or_suggestor
      ]
    }
  end

  def find_message_sender(update, ctx) do
    case update do
      %{"message" => %{"from" => %{"id" => user_id} = user, "chat" => %{"id" => chat_id}}} ->
        {
          :next,
          ctx: Map.put(ctx, :message_sender, %{user: user, user_id: user_id, chat_id: chat_id})
        }

      _ ->
        :next
    end
  end

  def update_user_meta(_update, %{persistence: persistence, message_sender: %{user: user}}) do
    CuteFemBot.Persistence.update_user_meta(persistence, user)
    :next
  end

  def moderation_or_suggestor(_update, %{
        message_sender: %{chat_id: cid},
        config: %{moderation_chat_id: moderation_chat_id}
      }) do
    branch =
      if cid == moderation_chat_id do
        # moderation
        [
          :empty_moderation_answer
        ]
      else
        # suggestor
        [
          :ignore_user_if_he_is_banned,
          :greet_user_if_start_command,
          :find_any_media,
          :handle_media
        ]
      end

    {:next, sub_branch: branch}
  end

  def empty_moderation_answer(_, %{api: api, config: %{moderation_chat_id: chat_id}}) do
    Api.send_message(api, %{
      "chat_id" => chat_id,
      "text" => "Я не знаю, зачем вы мне прислали сообщение"
    })

    :halt
  end

  def greet_user_if_start_command(update, ctx) do
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
        :next
    end
  end

  def ignore_user_if_he_is_banned(update, %{
        message_sender: %{user_id: uid},
        persistence: pers,
        api: api
      }) do
    banned_list = Persistence.get_ban_list(pers)

    if uid in banned_list do
      Api.send_message(api, %{"chat_id" => uid, "text" => "ты в бане"})
      :halt
    else
      :next
    end
  end

  def find_any_media(%{"message" => msg}, ctx) do
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
      :none -> :next
      some -> {:next, ctx: Map.put(ctx, :message_media, some)}
    end
  end

  def handle_media(update, ctx) do
    %{
      telegram_api: api,
      persistence: pers,
      message_sender: %{user_id: uid},
      config: %{moderation_chat_id: moder_chat_id}
    } = ctx

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
