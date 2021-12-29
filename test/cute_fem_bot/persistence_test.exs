defmodule CuteFemBotPersistenceTest do
  use ExUnit.Case

  setup do
    pid = start_supervised!(CuteFemBot.Persistence)
    %{pers: pid}
  end

  test "initially ban list is empty", %{pers: pers} do
    assert CuteFemBot.Persistence.get_ban_list(pers) == MapSet.new()
  end

  test "getting user meta for unknown user", %{pers: pers} do
    assert CuteFemBot.Persistence.get_user_meta(pers, 99) == :not_found
  end

  test "updating user meta", %{pers: pers} do
    assert CuteFemBot.Persistence.update_user_meta(pers, %{"id" => 1414, "first_name" => "Test"}) ==
             :ok

    assert CuteFemBot.Persistence.get_user_meta(pers, 1414) ==
             {:ok, %{"id" => 1414, "first_name" => "Test"}}
  end

  test "banning user", %{pers: pers} do
    CuteFemBot.Persistence.ban_user(pers, 9)

    assert 9 in CuteFemBot.Persistence.get_ban_list(pers)
  end

  test "unbanning user", %{pers: pers} do
    CuteFemBot.Persistence.ban_user(pers, 19)
    CuteFemBot.Persistence.unban_user(pers, 19)

    assert 19 not in CuteFemBot.Persistence.get_ban_list(pers)
  end
end
