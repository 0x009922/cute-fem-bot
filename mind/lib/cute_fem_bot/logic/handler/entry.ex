defmodule CuteFemBot.Logic.Handler.Entry do
  require Logger

  alias CuteFemBot.Logic.Handler
  alias Handler.Ctx
  alias CuteFemBot.Persistence

  def main() do
    [
      :fetch_config,
      :parse_update,
      :ignore_unknown,
      :update_user_meta,
      :router,
      :finalize
    ]
  end

  def fetch_config(ctx) do
    {:cont, Ctx.fetch_config(ctx)}
    # :halt
  end

  def parse_update(ctx) do
    result =
      case ctx.update do
        %{
          "message" =>
            %{
              "chat" => chat,
              "from" => user
            } = msg
        } ->
          {{:message, msg}, {chat, user}}

        %{
          "callback_query" =>
            %{
              "message" => %{
                "chat" => chat
              },
              "from" => user
            } = query
        } ->
          {{:callback_query, query}, {chat, user}}

        unknown ->
          {:unknown, unknown}
      end

    case result do
      {update, {chat, user}} ->
        {:cont,
         Map.put(ctx, :update, update)
         |> Map.put(:source, %{
           chat: chat,
           user: user,
           lang: Map.get(user, "language_code")
         })}

      {:unknown, _} = unknown ->
        {:cont, Map.put(ctx, :update, unknown)}
    end
  end

  def ignore_unknown(ctx) do
    case ctx.update do
      {:unknown, update} ->
        keys = Map.keys(update) |> Enum.filter(fn x -> x != "update_id" end)
        Logger.info("Update with keys #{keys} is ignored")
        :halt

      _ ->
        :cont
    end
  end

  def update_user_meta(ctx) do
    Persistence.update_user_meta(ctx.source.user)
    :cont
  end

  def router(ctx) do
    %{
      user: %{"id" => user_id},
      chat: %{"id" => chat_id, "type" => chat_type}
    } = ctx.source

    %CuteFemBot.Config{
      admins: admins,
      suggestions_chat: suggestions_chat
    } = Ctx.get_config(ctx)

    scope =
      cond do
        chat_id == suggestions_chat -> :suggestions_admin
        chat_id == user_id and user_id in admins -> :admin
        chat_type == "private" -> :suggestions
        true -> :confusing
      end

    case scope do
      :admin -> {:cont, :sub_mod, Handler.Admin, ctx}
      :suggestions_admin -> {:cont, :sub_mod, Handler.SuggestionsAdmin, ctx}
      :suggestions -> {:cont, :sub_mod, Handler.Suggestions, ctx}
      :confusing -> :cont
    end
  end

  def finalize(_ctx) do
    # TODO log and answer pending callback query
    :halt
  end
end
