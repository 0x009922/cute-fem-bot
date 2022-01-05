defmodule CuteFemBot.Logic.Handler.Middleware.Moderator.Shared do
  alias CuteFemBot.Logic.Handler.Ctx
  alias CuteFemBot.Telegram.Types.Message

  defdelegate send_msg!(ctx, msg), to: Ctx, as: :send_message_to_moderation!
  defdelegate set_chat_state!(ctx, state), to: Ctx, as: :set_moderation_chat_state!

  def raise_invalid_chat_state!(ctx, state) do
    send_msg!(ctx, %{
      "text" => """
      Ой, а у меня крыша потекла :|

      Попробуй /cancel
      """,
      parse_mode: "html"
    })

    raise "Ooops, invalid state: #{inspect(state)}"
  end

  def command_cancel(ctx) do
    is_there_any? =
      case ctx.moderation_chat_state do
        nil -> false
        _ -> true
      end

    set_chat_state!(ctx, nil)

    send_msg!(
      ctx,
      Message.with_text(
        if is_there_any?, do: "ОК, отменил", else: "ОК, отменил (а было ли что?..)"
      )
    )
  end
end
