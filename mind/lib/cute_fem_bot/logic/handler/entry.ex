defmodule CuteFemBot.Logic.Handler.Entry do
  require Logger
  use Traffic.Builder
  alias CuteFemBot.Logic.Handler
  alias Handler.Context
  alias CuteFemBot.Persistence

  over(:fetch_config)
  over(:parse_update)
  over(:ignore_unknown)
  over(:update_user_meta)
  over(:router)
  over(fn x -> halt(x) end)

  def fetch_config(ctx) do
    state = CuteFemBot.Config.State.lookup!()
    Context.put_config(ctx, state)
  end

  def parse_update(ctx) do
    ctx
    |> Context.parse_raw_update()
  end

  def ignore_unknown(ctx) do
    case Context.get_parsed_update!(ctx) do
      :unknown -> halt(ctx)
      _ -> ctx
    end
  end

  def update_user_meta(ctx) do
    user = Context.get_update_source!(ctx, :user)
    Persistence.update_user_meta(user)
    ctx
  end

  def router(ctx) do
    %{"id" => user_id} = Context.get_update_source!(ctx, :user)
    %{"id" => chat_id, "type" => chat_type} = Context.get_update_source!(ctx, :chat)

    %CuteFemBot.Config{
      admins: admins,
      suggestions_chat: suggestions_chat
    } = Context.get_config!(ctx)

    scope =
      cond do
        chat_id == suggestions_chat -> :suggestions_admin
        chat_id == user_id and user_id in admins -> :admin
        chat_type == "private" -> :suggestions
        true -> :confusing
      end

    case scope do
      :admin -> Traffic.move_on(ctx, [Handler.Admin])
      :suggestions_admin -> Traffic.move_on(ctx, [Handler.SuggestionsAdmin])
      :suggestions -> Traffic.move_on(ctx, [Handler.Suggestions])
      :confusing -> ctx
    end
  end
end
