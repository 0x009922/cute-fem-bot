defmodule CuteFemBotPersistenceTest do
  use ExUnit.Case

  alias CuteFemBot.Persistence

  setup do
    pid = start_supervised!(Persistence)
    %{pers: pid}
  end

  test "initially ban list is empty", %{pers: pers} do
    assert Persistence.get_ban_list(pers) == MapSet.new()
  end

  test "getting user meta for unknown user", %{pers: pers} do
    assert Persistence.get_user_meta(pers, 99) == :not_found
  end

  test "updating user meta", %{pers: pers} do
    assert Persistence.update_user_meta(pers, %{"id" => 1414, "first_name" => "Test"}) ==
             :ok

    assert Persistence.get_user_meta(pers, 1414) ==
             {:ok, %{"id" => 1414, "first_name" => "Test"}}
  end

  test "banning user", %{pers: pers} do
    Persistence.ban_user(pers, 9)

    assert 9 in Persistence.get_ban_list(pers)
  end

  test "unbanning user", %{pers: pers} do
    Persistence.ban_user(pers, 19)
    Persistence.unban_user(pers, 19)

    assert 19 not in Persistence.get_ban_list(pers)
  end

  test "registering suggestion and then fetching it", %{pers: pers} do
    data = %{
      user_id: 9,
      file_id: 4,
      type: :photo
    }

    assert Persistence.add_new_suggestion(pers, data) == :ok
    assert Persistence.bind_moderation_msg_to_suggestion(pers, 4, 99) == :ok
    assert Persistence.find_suggestion_by_moderation_msg(pers, 99) == {:ok, data}
  end

  test "suggestion not found if not added", %{pers: pers} do
    assert Persistence.find_suggestion_by_moderation_msg(pers, 10) == :not_found
  end

  test "approving media", %{pers: pers} do
    data = %{
      user_id: 9,
      file_id: 4,
      type: :photo
    }

    assert Persistence.add_new_suggestion(pers, data) == :ok
    assert Persistence.bind_moderation_msg_to_suggestion(pers, 4, 99) == :ok
    assert Persistence.approve_media(pers, 4) == :ok
    assert Persistence.find_suggestion_by_moderation_msg(pers, 99) == :not_found
    assert Persistence.get_approved_queue(pers) == [{:photo, 4}]
  end

  test "rejecting media", %{pers: pers} do
    data = %{
      user_id: 9,
      file_id: 4,
      type: :photo
    }

    assert Persistence.add_new_suggestion(pers, data) == :ok
    assert Persistence.bind_moderation_msg_to_suggestion(pers, 4, 99) == :ok
    assert Persistence.reject_media(pers, 4) == :ok
    assert Persistence.find_suggestion_by_moderation_msg(pers, 5) == :not_found
    assert Persistence.get_approved_queue(pers) == []
  end

  test "adding the same unapproved file again", %{pers: pers} do
    data = %{
      user_id: 9,
      file_id: 4,
      type: :photo
    }

    assert Persistence.add_new_suggestion(pers, data) == :ok
    assert Persistence.add_new_suggestion(pers, data) == :duplication
  end
end
