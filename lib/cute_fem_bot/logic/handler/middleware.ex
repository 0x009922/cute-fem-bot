defmodule CuteFemBot.Logic.Handler.Middleware do
  require Logger

  def main() do
    [
      :try_handle_message,
      :try_handle_query_callback,
      :ignore
    ]
  end

  def try_handle_message(%{update: update} = ctx) do
    case update do
      %{"message" => _} -> {:cont, :sub_mod, CuteFemBot.Logic.Handler.Middleware.Message, ctx}
      _ -> :cont
    end
  end

  def try_handle_query_callback(%{api: api, update: update}) do
    case update do
      %{"query_callback" => %{"id" => id}} ->
        CuteFemBot.Telegram.Api.request(api,
          method_name: "answerCallbackQuery",
          body: %{
            "callback_query_id" => id,
            "text" => "Я пока не умею работать с кверями :/"
          }
        )

        :halt

      _ ->
        :cont
    end
  end

  def ignore(ctx) do
    Logger.debug("Ignoring update, ctx: #{inspect(ctx)}")
    :halt
  end
end
