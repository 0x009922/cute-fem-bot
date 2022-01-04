defmodule CuteFemBot.Logic.Handler.Ctx do
  alias CuteFemBot.Telegram.Types.Message

  def new(deps, update) do
    %{deps: deps, update: update}
  end

  def deps_api(%{deps: %{api: api}}), do: api
  def deps_persistence(%{deps: %{persistence: x}}), do: x
  def deps_config(%{deps: %{config: x}}), do: x
  def deps_posting(%{deps: %{posting: x}}), do: x

  def fetch_config(ctx) do
    Map.put(ctx, :config, CuteFemBot.Config.State.get(deps_config(ctx)))
  end

  def get_config(%{config: x}), do: x

  def send_message_to_moderation!(ctx, body) do
    {:ok, x} =
      CuteFemBot.Telegram.Api.send_message(
        ctx.deps.api,
        Message.new()
        |> Message.set_chat_id(ctx.config.moderation_chat_id)
        |> Message.set_parse_mode("html")
        |> Map.merge(body)
      )

    x
  end
end
