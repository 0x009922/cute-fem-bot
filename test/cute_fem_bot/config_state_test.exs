defmodule CuteFemBotConfigStateTest do
  use ExUnit.Case

  defp cfg_factory() do
    %CuteFemBot.Config{
      api_token: "",
      suggestions_chat: 0,
      posting_chat: 0,
      admins: [],
      master: 0
    }
  end

  test "init and use config" do
    cfg = cfg_factory()

    assert {:ok, table} = CuteFemBot.Config.State.init(cfg)
    assert CuteFemBot.Config.State.lookup!(table) == cfg
  end
end
