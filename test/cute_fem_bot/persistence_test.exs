defmodule CuteFemBotPersistenceTest do
  use ExUnit.Case

  alias CuteFemBot.Persistence
  alias CuteFemBot.Core.Suggestion

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(CuteFemBot.Repo)
  end

  test "initially ban list is empty" do
    assert Persistence.get_ban_list() == MapSet.new()
  end

  test "unbanning user that is not banned" do
    assert Persistence.unban_user(999) == :ok
  end

  test "getting user meta for unknown user" do
    assert Persistence.get_user_meta(99) == :not_found
  end

  test "updating user meta" do
    assert Persistence.update_user_meta(%{"id" => 1414, "first_name" => "Test"}) ==
             :ok

    assert Persistence.get_user_meta(1414) ==
             {:ok, %{"id" => 1414, "first_name" => "Test"}}
  end

  test "banning user" do
    Persistence.ban_user(9)

    assert 9 in Persistence.get_ban_list()
  end

  test "unbanning user" do
    Persistence.ban_user(19)
    Persistence.unban_user(19)

    assert 19 not in Persistence.get_ban_list()
  end

  test "registering suggestion and then fetching it" do
    data = Suggestion.new(:photo, "file", 9)

    assert Persistence.add_new_suggestion(data) == :ok
    assert Persistence.bind_moderation_msg_to_suggestion("file", 99) == :ok

    assert Persistence.find_suggestion_by_moderation_msg(99) ==
             {:ok, data |> Suggestion.bind_decision_message(99)}
  end

  test "suggestion not found if not added" do
    assert Persistence.find_suggestion_by_moderation_msg(10) == :not_found
  end

  test "approving media" do
    data = Suggestion.new(:photo, "file1", 9)

    assert Persistence.add_new_suggestion(data) == :ok
    assert Persistence.bind_moderation_msg_to_suggestion("file1", 99) == :ok
    assert Persistence.approve_media("file1", :sfw) == :ok
    assert Persistence.find_suggestion_by_moderation_msg(99) == :not_found

    assert Persistence.get_approved_queue(:sfw) == [
             data
           ]

    assert Persistence.get_approved_queue(:nsfw) == []
  end

  test "rejecting media" do
    data = Suggestion.new(:photo, "photo", 9)

    assert Persistence.add_new_suggestion(data) == :ok
    assert Persistence.bind_moderation_msg_to_suggestion("photo", 99) == :ok
    assert Persistence.reject_media("photo") == :ok
    assert Persistence.find_suggestion_by_moderation_msg(5) == :not_found
    assert Persistence.get_approved_queue(:sfw) == []
    assert Persistence.get_approved_queue(:nsfw) == []
  end

  test "adding the same unapproved file again" do
    data = Suggestion.new(:photo, "photo", 9)

    assert Persistence.add_new_suggestion(data) == :ok
    assert_raise(Ecto.ConstraintError, fn -> Persistence.add_new_suggestion(data) end)
  end

  test "committing files flushing" do
    file1 = Suggestion.new(:photo, "0", 0)
    file2 = Suggestion.new(:photo, "1", 0)

    [
      file1,
      file2
    ]
    |> Enum.each(fn f ->
      Persistence.add_new_suggestion(f)
      Persistence.approve_media(f.file_id, :nsfw)
    end)

    Persistence.check_as_published(["1", "0"])

    assert Persistence.get_approved_queue(:nsfw) == []
  end

  test "setting & getting chat states" do
    assert Persistence.get_chat_state("55") == nil
    assert Persistence.set_chat_state("55", :test) == :ok
    assert Persistence.get_chat_state("55") == :test
    assert Persistence.get_chat_state("99") == nil
    assert Persistence.set_chat_state("55", :foo) == :ok
    assert Persistence.get_chat_state("55") == :foo
  end

  test "cancelling approved suggestion" do
    suggestion = Suggestion.new(:photo, "nya", 9919)

    Persistence.add_new_suggestion(suggestion)
    Persistence.approve_media("nya", :sfw)

    assert Persistence.cancel_approved("nya") == :ok
    assert Persistence.get_approved_queue(:sfw) == []
  end
end
