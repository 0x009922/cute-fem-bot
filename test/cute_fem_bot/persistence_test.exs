defmodule CuteFemBotPersistenceTest do
  use ExUnit.Case

  alias CuteFemBot.Persistence
  alias CuteFemBot.Core.Suggestion

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
    data = Suggestion.new(:photo, 4, 9)

    assert Persistence.add_new_suggestion(pers, data) == :ok
    assert Persistence.bind_moderation_msg_to_suggestion(pers, 4, 99) == :ok

    assert Persistence.find_suggestion_by_moderation_msg(pers, 99) ==
             {:ok, data |> Suggestion.bind_moderation_msg(99)}
  end

  test "suggestion not found if not added", %{pers: pers} do
    assert Persistence.find_suggestion_by_moderation_msg(pers, 10) == :not_found
  end

  test "approving media", %{pers: pers} do
    data = Suggestion.new(:photo, 4, 9)

    assert Persistence.add_new_suggestion(pers, data) == :ok
    assert Persistence.bind_moderation_msg_to_suggestion(pers, 4, 99) == :ok
    assert Persistence.approve_media(pers, 4) == :ok
    assert Persistence.find_suggestion_by_moderation_msg(pers, 99) == :not_found
    assert Persistence.get_approved_queue(pers) == [data |> Suggestion.bind_moderation_msg(99)]
  end

  test "rejecting media", %{pers: pers} do
    data = Suggestion.new(:photo, 4, 9)

    assert Persistence.add_new_suggestion(pers, data) == :ok
    assert Persistence.bind_moderation_msg_to_suggestion(pers, 4, 99) == :ok
    assert Persistence.reject_media(pers, 4) == :ok
    assert Persistence.find_suggestion_by_moderation_msg(pers, 5) == :not_found
    assert Persistence.get_approved_queue(pers) == []
  end

  test "adding the same unapproved file again", %{pers: pers} do
    data = Suggestion.new(:photo, 4, 9)

    assert Persistence.add_new_suggestion(pers, data) == :ok
    assert Persistence.add_new_suggestion(pers, data) == :duplication
  end

  test "committing files posting", %{pers: pers} do
    file1 = Suggestion.new(:photo, 0, 0)
    file2 = Suggestion.new(:photo, 1, 0)

    [
      file1,
      file2
    ]
    |> Enum.each(fn f ->
      Persistence.add_new_suggestion(pers, f)
      Persistence.approve_media(pers, f.file_id)
    end)

    Persistence.files_posted(pers, [1, 0])

    assert Persistence.get_approved_queue(pers) == []
  end

  test "setting & getting admin chat states", %{pers: pers} do
    assert Persistence.get_admin_chat_state(pers, 55) == nil
    assert Persistence.set_admin_chat_state(pers, 55, :test) == :ok
    assert Persistence.get_admin_chat_state(pers, 55) == :test
    assert Persistence.get_admin_chat_state(pers, 99) == nil
    assert Persistence.set_admin_chat_state(pers, 55, :foo) == :ok
    assert Persistence.get_admin_chat_state(pers, 55) == :foo
  end

  test "cancelling approved suggestion", %{pers: pers} do
    suggestion = Suggestion.new(:photo, "nya", 9919)

    Persistence.add_new_suggestion(pers, suggestion)
    Persistence.approve_media(pers, "nya")

    assert Persistence.cancel_approved(pers, "nya") == :ok
    assert Persistence.get_approved_queue(pers) == []
  end
end
