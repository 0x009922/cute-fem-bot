defmodule CuteFemBot.Logic.Handler.Admin.Shared do
  alias Telegram.Types.Message
  alias CuteFemBot.Logic.Handler.Context

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
      Telegram.Api.send_message(
        Context.get_dep!(ctx, :telegram),
        Message.new()
        |> Message.set_chat_id(get_admin_id!(ctx))
        |> Message.set_parse_mode("html")
        |> Map.merge(body)
      )

    x
  end

  def set_chat_state!(ctx, state) do
    :ok =
      CuteFemBot.Persistence.set_chat_state(
        "admin-#{get_admin_id!(ctx)}",
        state
      )
  end

  def get_admin_id!(ctx) do
    %{"id" => x} = Context.get_update_source!(ctx, :user)
    x
  end
end
