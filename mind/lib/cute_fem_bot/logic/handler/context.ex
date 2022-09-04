defmodule CuteFemBot.Logic.Handler.Context do
  use TypedStruct

  alias Traffic.Context, as: Ctx

  def put_deps(%Ctx{} = ctx, %{telegram: _, posting: _, web_auth: _} = deps) do
    Ctx.assign(ctx, :deps, deps)
  end

  def get_dep!(%Ctx{assigns: %{deps: %{telegram: value}}}, :telegram), do: value
  # def get_dep!(%Ctx{assigns: %{deps: %{config: value}}}, :config), do: value
  def get_dep!(%Ctx{assigns: %{deps: %{posting: value}}}, :posting), do: value
  def get_dep!(%Ctx{assigns: %{deps: %{web_auth: value}}}, :web_auth), do: value

  def put_config(%Ctx{} = ctx, %CuteFemBot.Config{} = state) do
    Ctx.assign(ctx, :config, state)
  end

  def get_config!(%Ctx{assigns: %{config: %CuteFemBot.Config{} = state}}), do: state

  def get_config_suggestions_chat!(%Ctx{} = ctx) do
    with %CuteFemBot.Config{} = cfg <- get_config!(ctx), do: cfg.suggestions_chat
  end

  def put_raw_update(%Ctx{} = ctx, value), do: Ctx.assign(ctx, :update_raw, value)

  def parse_raw_update(%Ctx{} = ctx) do
    case ctx.assigns.update_raw do
      %{
        "message" =>
          %{
            "chat" => chat,
            "from" => user
          } = msg
      } ->
        ctx
        |> Ctx.assign(:update_parsed, {:message, msg})
        |> Ctx.assign(:update_from_user, user)
        |> Ctx.assign(:update_from_chat, chat)
        |> Ctx.assign(:update_user_lang, user_lang(user))
        |> Ctx.assign(:message_commands, CuteFemBot.Util.find_all_commands(msg))

      %{
        "callback_query" =>
          %{
            "message" => %{
              "chat" => chat
            },
            "from" => user
          } = query
      } ->
        ctx
        |> Ctx.assign(:update_parsed, {:callback_query, query})
        |> Ctx.assign(:update_from_user, user)
        |> Ctx.assign(:update_from_chat, chat)
        |> Ctx.assign(:update_user_lang, user_lang(user))

      _unknown ->
        ctx
        |> Ctx.assign(:update_parsed, :unknown)
    end
  end

  def get_parsed_update!(%Ctx{assigns: %{update_parsed: value}}), do: value

  def get_update_source!(%Ctx{assigns: %{update_from_user: value}}, :user), do: value
  def get_update_source!(%Ctx{assigns: %{update_from_chat: value}}, :chat), do: value

  def get_update_user_lang!(%Ctx{assigns: %{update_user_lang: value}}), do: value

  def get_message_commands(%Ctx{assigns: %{message_commands: value}}), do: value
  def get_message_commands(_), do: nil

  def has_command?(%Ctx{assigns: %{message_commands: %{} = cmds}}, command)
      when is_binary(command) do
    Map.has_key?(cmds, command)
  end

  def has_command?(%Ctx{}, _cmd), do: false

  def put_admin_chat_state(%Ctx{} = ctx, state) do
    Ctx.assign(ctx, :admin_chat_state, state)
  end

  def get_admin_chat_state!(%Ctx{assigns: %{admin_chat_state: state}}), do: state

  defp user_lang(%{"language_code" => x}), do: x
end
