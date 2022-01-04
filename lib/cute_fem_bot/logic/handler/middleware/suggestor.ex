defmodule CuteFemBot.Logic.Handler.Middleware.Suggestor do
  alias CuteFemBot.Telegram.Types.Message
  alias CuteFemBot.Telegram.Api
  alias CuteFemBot.Persistence
  alias CuteFemBot.Core.Suggestion
  alias CuteFemBot.Logic.Handler.Ctx

  def main() do
    [
      :extract_sender,
      :handle_banlist,
      :handle_commands,
      :handle_suggestion,
      :finalize
    ]
  end

  def extract_sender(ctx) do
    {:message, %{"from" => user}} = ctx.update
    {:cont, Map.put(ctx, :sender, user)}
  end

  def handle_banlist(ctx) do
    ban_list = Persistence.get_ban_list(Ctx.deps_persistence(ctx))
    %{"id" => uid} = ctx.sender

    if uid in ban_list do
      case ctx.update do
        {:message, %{"message_id" => msg_id}} ->
          send_msg!(
            ctx,
            Message.with_text("Ты в бане, не пиши мне больше") |> Message.set_reply_to(msg_id)
          )

        {:callback_query, %{"id" => query_id}} ->
          Api.answer_callback_query(Ctx.deps_api(ctx), query_id)
      end

      :halt
    else
      :cont
    end
  end

  def handle_commands(ctx) do
    case ctx.update do
      {:message, %{"text" => txt}} ->
        cmds = CuteFemBot.Util.find_all_commands(txt)

        case cmds do
          %{"start" => _} ->
            command_start(ctx)
            :halt

          _ ->
            :cont
        end

      _ ->
        :cont
    end
  end

  def handle_suggestion(ctx) do
    case ctx.update do
      {:message, %{"message_id" => msg_id} = msg} ->
        case Suggestion.extract_from_message(msg) do
          :none ->
            send_msg!(ctx, Message.with_text("Туть ничего неть") |> Message.set_reply_to(msg_id))
            :halt

          {:ok, item} ->
            handle_media(ctx, item)
            :halt
        end

      _ ->
        :cont
    end
  end

  def finalize(ctx) do
    case ctx.update do
      {:callback_query, query} ->
        CuteFemBot.Telegram.Api.answer_callback_query(ctx.deps.api, query["id"])

      {:message, _} ->
        # it should be already proceed in "handle_suggestion"
        :halt
    end

    :halt
  end

  defp command_start(ctx) do
    send_msg!(
      ctx,
      Message.with_text("""
      Привет

      Я люблю контент с милыми парнями. Пришли мне.
      Пнимаю <b>фотографии</b>, <b>видео</b> и <b>гифки</b>.
      Как в сжиженном виде, так и нет. Остальное не понимаю.
      """)
    )
  end

  defp handle_media(ctx, %Suggestion{file_id: file_id, type: type} = media) do
    {:message, %{"message_id" => message_id}} = ctx.update
    sender = ctx.sender
    uid = sender["id"]

    case Persistence.find_existing_unapproved_suggestion_by_file_id(
           Ctx.deps_persistence(ctx),
           file_id
         ) do
      :not_found ->
        :ok =
          Persistence.add_new_suggestion(
            Ctx.deps_persistence(ctx),
            Suggestion.new(type, file_id, uid)
          )

        {:ok, %{"message_id" => msg_id}} = notify_suggestion(ctx, media)

        :ok =
          Persistence.bind_moderation_msg_to_suggestion(
            Ctx.deps_persistence(ctx),
            file_id,
            msg_id
          )

        Api.send_message(Ctx.deps_api(ctx), %{
          "chat_id" => uid,
          "text" => "Спасибочки, принял 0w0",
          "reply_to_message_id" => message_id
        })

      {:ok, _} ->
        Api.send_message(Ctx.deps_api(ctx), %{
          "chat_id" => uid,
          "text" => "Этот файл уже рассматривается модераторами",
          "reply_to_message_id" => message_id
        })
    end
  end

  defp notify_suggestion(ctx, %Suggestion{} = media) do
    user_formatted = CuteFemBot.Util.format_user_name(ctx.sender, :html)
    caption = "Предложка от #{user_formatted}"

    %{method_name: method, body_part: media_body_part} = Suggestion.to_send(media)

    Api.request(
      Ctx.deps_api(ctx),
      method_name: method,
      body:
        %{
          "chat_id" => ctx.config.moderation_chat_id,
          "caption" => caption,
          "parse_mode" => "html",
          "reply_markup" => %{
            "inline_keyboard" => [
              [
                inline_reply_btn("Ня", "approve"),
                inline_reply_btn("Не ня", "reject"),
                inline_reply_btn("Бан", "ban")
              ]
            ]
          }
        }
        |> Map.merge(media_body_part)
    )
  end

  defp inline_reply_btn(text, callback_data) do
    %{"text" => text, "callback_data" => callback_data}
  end

  defp send_msg!(ctx, body) do
    {:ok, x} =
      Api.send_message(
        Ctx.deps_api(ctx),
        Message.new()
        |> Message.set_chat_id(ctx.sender["id"])
        |> Message.set_parse_mode("html")
        |> Map.merge(body)
      )

    x
  end
end
