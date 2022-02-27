defmodule CuteFemBot.Logic.Handler.Ctx do
  def new(deps, update) do
    %{deps: deps, update: update}
  end

  def deps_api(%{deps: %{api: api}}), do: api
  def deps_config(%{deps: %{config: x}}), do: x
  def deps_posting(%{deps: %{posting: x}}), do: x

  def fetch_config(ctx) do
    Map.put(ctx, :config, CuteFemBot.Config.State.lookup!(deps_config(ctx)))
  end

  def get_config(%{config: %CuteFemBot.Config{} = cfg}), do: cfg

  def cfg_get_suggestions_chat(%{config: %CuteFemBot.Config{suggestions_chat: val}}), do: val
end
