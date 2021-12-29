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
          Map.put(ctx, :message_sender, %{user: user, user_id: user_id, chat_id: chat_id})
        }

      _ ->
        :cont
    end
  end

  def update_user_meta(%{message_sender: %{user: user}} = ctx) do
    CuteFemBot.Persistence.update_user_meta(ctx_deps_pers(ctx), user)
    :cont
  end

  def moderation_or_suggestor(
        %{
          message_sender: %{chat_id: cid},
          config: %CuteFemBot.Config{moderation_chat_id: moderation_chat_id}
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

  def empty_moderation_answer(%{config: %{moderation_chat_id: chat_id}} = ctx) do
    Api.send_message(ctx_deps_api(ctx), %{
      "chat_id" => chat_id,
      "text" => "Я не знаю, зачем вы мне прислали сообщение o_O"
    })

    :halt
  end

  def greet_user_if_start_command(%{update: update} = ctx) do
    case update do
      %{"message" => %{"text" => "/start"}} ->
        %{message_sender: %{user_id: uid}} = ctx

        CuteFemBot.Telegram.Api.request(
          ctx_deps_api(ctx),
          method_name: "sendMessage",
          body: %{
            "chat_id" => uid,
            "text" => "Ня :з"
          }
        )

        :halt

      _ ->
        :cont
    end
  end

  def fetch_ban_list(ctx) do
    {:cont, Map.put(ctx, :banned_users, Persistence.get_ban_list(ctx_deps_pers(ctx)))}
  end

  def ignore_user_if_he_is_banned(
        %{
          message_sender: %{user_id: uid},
          banned_users: banned_list
        } = ctx
      ) do
    if uid in banned_list do
      Api.send_message(ctx_deps_api(ctx), %{"chat_id" => uid, "text" => ">:("})
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
          message_sender: %{user_id: uid, user: sender},
          config: %{moderation_chat_id: moder_chat_id}
        } = ctx
      ) do
    %{"message" => %{"message_id" => message_id}} = update

    case ctx do
      %{:message_media => media} ->
        {:ok, %{"message_id" => _moderation_message_id}} =
          notify_suggestion(%{
            moder_chat_id: moder_chat_id,
            sender: sender,
            api: ctx_deps_api(ctx),
            media: media
          })

        # Persistence.add_new_suggestion(ctx_deps_pers(ctx), media, moderation_message_id)

        Api.send_message(ctx_deps_api(ctx), %{
          "chat_id" => uid,
          "text" => "Спасибочки, принял 0w0",
          "reply_to_message_id" => message_id
        })

        :halt

      _ ->
        Api.send_message(ctx_deps_api(ctx), %{
          "chat_id" => uid,
          "text" => "Не-не-не... мне нужны только фотки",
          "reply_to_message_id" => message_id
        })

        :halt
    end
  end

  defp ctx_deps_api(%{deps: %{api: x}}) do
    x
  end

  defp ctx_deps_pers(%{deps: %{persistence: x}}) do
    x
  end

  defp notify_suggestion(%{moder_chat_id: chat_id, media: media, sender: sender, api: api}) do
    user_formatted = CuteFemBot.Util.format_user_name(sender)
    caption = "Предложка от #{user_formatted}"
    {type, file_id} = media
    ty_str = Atom.to_string(type)
    method = "send" <> String.capitalize(ty_str)

    Api.request(
      api,
      method_name: method,
      body:
        %{
          "chat_id" => chat_id,
          "caption" => caption,
          "parse_mode" => "markdown"
        }
        |> Map.put(ty_str, file_id)
    )
  end
end
