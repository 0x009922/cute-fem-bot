defmodule CuteFemBotPersistenceTest do
  use ExUnit.Case
  @moduletag :integration

  alias CuteFemBot.Persistence
  alias CuteFemBot.Schema.Suggestion

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

    assert {:ok, data} = Persistence.find_suggestion_by_moderation_msg(99)
    assert data.decision_msg_id == 99
  end

  test "suggestion not found if not added" do
    assert Persistence.find_suggestion_by_moderation_msg(10) == :not_found
  end

  test "approving media" do
    data = Suggestion.new(:photo, "file1", 9)

    assert Persistence.add_new_suggestion(data) == :ok
    assert Persistence.bind_moderation_msg_to_suggestion("file1", 99) == :ok
    assert Persistence.make_decision("file1", 52, ~U[2024-01-02 12:00:00.005Z], :sfw) == :ok
    assert Persistence.find_suggestion_by_moderation_msg(99) == :not_found
    assert Persistence.get_approved_queue(:sfw) |> only_file_ids == [data] |> only_file_ids
    assert Persistence.get_approved_queue(:nsfw) == []
  end

  test "rejecting media" do
    data = Suggestion.new(:photo, "photo", 9)

    assert Persistence.add_new_suggestion(data) == :ok
    assert Persistence.bind_moderation_msg_to_suggestion("photo", 99) == :ok
    assert Persistence.make_decision("photo", 52, ~U[2024-01-02 12:00:00Z], :reject) == :ok
    assert Persistence.find_suggestion_by_moderation_msg(5) == :not_found
    assert Persistence.get_approved_queue(:sfw) == []
    assert Persistence.get_approved_queue(:nsfw) == []
  end

  test "approved queue order is specified by decision date" do
    [
      {Suggestion.new(:photo, "id-1", 0), ~U[2024-01-02 12:00:00Z]},
      {Suggestion.new(:photo, "id-2", 0), ~U[2024-01-02 15:00:00Z]},
      {Suggestion.new(:photo, "id-3", 0), ~U[2024-01-02 14:00:00Z]},
      {Suggestion.new(:photo, "id-4", 0), ~U[2024-01-02 09:00:00Z]}
    ]
    |> Enum.each(fn {suggestion, decision_at} ->
      Persistence.add_new_suggestion(suggestion)
      Persistence.make_decision(suggestion.file_id, 0, decision_at, :sfw)
    end)

    assert Persistence.get_approved_queue(:sfw) |> only_file_ids() == [
             "id-4",
             "id-1",
             "id-3",
             "id-2"
           ]
  end

  test "making decision doesn't fail if `made_at` has microseconds" do
    assert Persistence.add_new_suggestion(Suggestion.new(:photo, "id-1", 1)) == :ok
    assert Persistence.make_decision("id-1", 1, ~U[2020-10-10 01:00:00.41242Z], :reject) == :ok
  end

  test "adding the same unapproved file again" do
    data = Suggestion.new(:photo, "photo", 9)

    assert Persistence.add_new_suggestion(data) == :ok
    assert_raise(Ecto.ConstraintError, fn -> Persistence.add_new_suggestion(data) end)
  end

  test "checking suggestions as published" do
    file1 = Suggestion.new(:photo, "0", 0)
    file2 = Suggestion.new(:photo, "1", 0)

    [
      file1,
      file2
    ]
    |> Enum.each(fn f ->
      Persistence.add_new_suggestion(f)
      Persistence.make_decision(f.file_id, 0, ~U[2020-10-10 00:00:00Z], :nsfw)
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

  test "cancelling decision" do
    suggestion = Suggestion.new(:photo, "nya", 9919)

    Persistence.add_new_suggestion(suggestion)
    Persistence.make_decision("nya", 12, ~U[2020-10-10 00:00:00Z], :sfw)

    assert Persistence.cancel_decision("nya") == :ok
    assert Persistence.get_approved_queue(:sfw) == []
  end

  test "when making decision after post was published, error is returned" do
    Persistence.add_new_suggestion(Suggestion.new(:photo, "nya", 9919))
    Persistence.make_decision("nya", 12, ~U[2020-10-10 00:00:00Z], :sfw)
    Persistence.check_as_published(["nya"])

    assert Persistence.make_decision("nya", 41, ~U[2020-10-10 00:00:00Z], :nsfw) ==
             {:error, :published}
  end

  test "when making decision for unexisting post, error is returned" do
    assert Persistence.make_decision("nya", 12, ~U[2020-10-10 00:00:00Z], :sfw) ==
             {:error, :not_found}
  end

  describe "Working with schedule" do
    test "When it is not set, nil is returned" do
      assert Persistence.get_schedule() == nil
    end

    test "When it is set, value is returned" do
      {:ok, value} = CuteFemBot.Core.Schedule.Complex.from_raw("sfw;1;*")

      Persistence.set_schedule(value)

      assert Persistence.get_schedule() == value
    end

    test "When value is updated, new value is returned" do
      {:ok, v1} = CuteFemBot.Core.Schedule.Complex.from_raw("sfw;1;*")
      {:ok, v2} = CuteFemBot.Core.Schedule.Complex.from_raw("nsfw;2;*")

      Persistence.set_schedule(v1)
      Persistence.set_schedule(v2)

      assert Persistence.get_schedule() == v2
    end
  end

  defp only_file_ids(items) do
    Enum.map(items, fn %Suggestion{file_id: x} -> x end)
  end
end
