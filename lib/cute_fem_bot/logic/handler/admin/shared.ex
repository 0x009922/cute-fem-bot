defmodule CuteFemBot.Logic.Handler.Admin.Shared do
  alias CuteFemBot.Logic.Handler.Ctx
  alias CuteFemBot.Telegram.Types.Message

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

  @doc """
  Sends message back to sender (which is supposed to be an admin)
  """
  def send_msg!(ctx, body) do
    {:ok, x} =
      CuteFemBot.Telegram.Api.send_message(
        ctx.deps.api,
        Message.new()
        |> Message.set_chat_id(get_admin_id(ctx))
        |> Message.set_parse_mode("html")
        |> Map.merge(body)
      )

    x
  end

  def set_chat_state!(ctx, state) do
    :ok =
      CuteFemBot.Persistence.set_admin_chat_state(
        Ctx.deps_persistence(ctx),
        get_admin_id(ctx),
        state
      )
  end

  def command_cancel(ctx) do
    is_there_any? =
      case chat_state(ctx) do
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

  @doc """
  Gets admin id from ctx.sender and puts it in ctx.admin_chat_state
  """
  def fetch_chat_state(ctx) do
    Map.put(
      ctx,
      :admin_chat_state,
      CuteFemBot.Persistence.get_admin_chat_state(
        Ctx.deps_persistence(ctx),
        get_admin_id(ctx)
      )
    )
  end

  @doc """
  Extracts chat state from ctx.admin_chat_state
  """
  def chat_state(%{admin_chat_state: state}), do: state

  def get_admin_id(%{source: %{user: %{"id" => admin_id}}}), do: admin_id
end
