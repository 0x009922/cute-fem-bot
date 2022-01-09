defmodule CuteFemBot.Logic.Handler.Entry do
  require Logger

  alias CuteFemBot.Logic.Handler
  alias Handler.Ctx
  alias CuteFemBot.Persistence

  def main() do
    [
      :fetch_config,
      :parse_update,
      :update_user_meta,
      :router,
      :finalize
    ]
  end

  def fetch_config(ctx) do
    {:cont, Ctx.fetch_config(ctx)}
  end

  def parse_update(ctx) do
    {update, {chat, user}} =
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
      end

    {:cont,
     Map.put(ctx, :update, update)
     |> Map.put(:source, %{
       chat: chat,
       user: user,
       lang: Map.get(user, "language_code")
     })}
  end

  def update_user_meta(ctx) do
    Persistence.update_user_meta(Ctx.deps_persistence(ctx), ctx.source.user)
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
        user_id in admins -> :admin
        chat_id == suggestions_chat -> :suggestions_admin
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
