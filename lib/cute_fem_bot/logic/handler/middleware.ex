defmodule CuteFemBot.Logic.Handler.Middleware do
  require Logger

  alias CuteFemBot.Logic.Handler.Ctx
  alias CuteFemBot.Logic.Handler.Middleware.Moderator
  alias CuteFemBot.Logic.Handler.Middleware.Suggestor

  def main() do
    [
      :fetch_config,
      :high_level_update_parsing
    ]
  end

  def fetch_config(ctx) do
    {:cont, Ctx.fetch_config(ctx)}
  end

  def high_level_update_parsing(ctx) do
    %CuteFemBot.Config{moderation_chat_id: mod_chat_id} = Ctx.get_config(ctx)

    parsed =
      case ctx.update do
        %{"message" => %{"chat" => %{"id" => chat_id}} = msg} ->
          if chat_id == mod_chat_id do
            {:moderator, {:message, msg}}
          else
            {:suggestor, {:message, msg}}
          end

        %{"callback_query" => callback} ->
          branch =
            case callback do
              %{"message" => %{"chat" => %{"id" => chat_id, "type" => chat_type}}} ->
                cond do
                  chat_id == mod_chat_id -> :moderator
                  chat_type == "private" -> :suggestor
                  true -> :unknown
                end

              _ ->
                :unknown
            end

          case branch do
            :unknown -> {:bad_callback_query, callback}
            role -> {role, {:callback_query, callback}}
          end

        _ ->
          :skip
      end

    case parsed do
      {:moderator, update} ->
        {:cont, :sub_mod, Moderator, Map.put(ctx, :update, update)}

      {:suggestor, update} ->
        {:cont, :sub_mod, Suggestor, Map.put(ctx, :update, update)}

      :skip ->
        Logger.info("Update is ignored: #{inspect(ctx.update)}")
        :halt

      {:bad_callback_query, %{"id" => query_id}} ->
        CuteFemBot.Telegram.Api.request!(
          Ctx.deps_api(ctx),
          method_name: "answerCallbackQuery",
          body: %{
            "callback_query_id" => query_id,
            "text" => "Ответить не могу ничем :|"
          }
        )

        :halt
    end
  end
end
