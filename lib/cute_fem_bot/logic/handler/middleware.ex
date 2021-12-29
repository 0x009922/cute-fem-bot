defmodule CuteFemBot.Logic.Handler.Middleware do
  require Logger

  def main() do
    [
      :fetch_config,
      :try_handle_message,
      :try_handle_query_callback,
      :ignore
    ]
  end

  def fetch_config(ctx) do
    {:cont, Map.put(ctx, :config, CuteFemBot.Config.State.get(ctx.deps.config))}
  end

  def try_handle_message(%{update: update} = ctx) do
    case update do
      %{"message" => _} ->
        {:cont, :sub_mod, CuteFemBot.Logic.Handler.Middleware.Message, ctx}

      _ ->
        :cont
    end
  end

  def try_handle_query_callback(%{update: update, deps: %{api: api}}) do
    case update do
      %{"callback_query" => %{"id" => id}} ->
        CuteFemBot.Telegram.Api.request(
          api,
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
