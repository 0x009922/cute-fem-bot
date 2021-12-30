defmodule CuteFemBot.Logic.Handler.Ctx do
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
end
