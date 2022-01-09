defmodule CuteFemBotCorePostingTest do
  use ExUnit.Case

  alias CuteFemBot.Core.Posting

  test "new item is incomplete" do
    assert Posting.new() |> Posting.is_complete?() == false
  end

  test "parses correct cron expression" do
    assert {:ok, _} = Posting.new() |> Posting.put_raw_cron("* * * * *")
  end

  test "parses incorrect cron expression" do
    assert {:error, err} = Posting.new() |> Posting.put_raw_cron("henno?")
    assert is_binary(err)
  end

  test "parses correct fixed flushing" do
    assert {:ok, _} = Posting.new() |> Posting.put_raw_flush("5")
  end

  test "parses correct range flushing" do
    assert {:ok, _} = Posting.new() |> Posting.put_raw_flush("1-5")
  end

  test "parses range & fixed flushing even if it contains spaces" do
    ["   123 ", "5-9   ", " 14     - 20 "]
    |> Enum.each(fn x ->
      assert {:ok, _} = Posting.new() |> Posting.put_raw_flush(x)
    end)
  end

  test "error if in range flushing right is greater than left" do
    assert {:error, :invalid_flushing} = Posting.new() |> Posting.put_raw_flush("5-3")
  end

  test "some error flushing cases" do
    [
      "1.5",
      "1.5-5.6",
      "henno?",
      "5b10"
    ]
    |> Enum.each(fn x ->
      assert {:error, :invalid_flushing} = Posting.new() |> Posting.put_raw_flush(x)
    end)
  end

  test "not complete after cron parsing" do
    {:ok, x} = Posting.new() |> Posting.put_raw_cron("* * * * *")

    assert Posting.is_complete?(x) == false
  end

  test "not complete after flush parsing" do
    {:ok, x} = Posting.new() |> Posting.put_raw_flush("5")

    assert Posting.is_complete?(x) == false
  end

  test "complete after flush & cron parsing" do
    state =
      with {:ok, x} <- Posting.new() |> Posting.put_raw_flush("5"),
           {:ok, x} <- Posting.put_raw_cron(x, "* * * * *"),
           do: x

    assert Posting.is_complete?(state) == true
  end

  test "computing next posting time" do
    {:ok, x} = Posting.new() |> Posting.put_raw_cron("30 * * * *")
    {:ok, x} = Posting.put_raw_flush(x, "5")

    now = DateTime.from_naive!(~N[2020-05-10 04:23:55], "Europe/Moscow")
    expected = DateTime.from_naive!(~N[2020-05-10 04:30:00], "Europe/Moscow")

    assert Posting.compute_next_posting_time_msk(x, now) == {:ok, expected}
  end

  test "computing next posting time correctly even if input time is in UTC" do
    {:ok, x} = Posting.new() |> Posting.put_raw_cron("0 10 * * *")
    {:ok, x} = Posting.put_raw_flush(x, "5")

    now = ~U[2020-05-10 05:00:00Z]
    expected = DateTime.from_naive!(~N[2020-05-10 10:00:00], "Europe/Moscow")

    assert Posting.compute_next_posting_time_msk(x, now) == {:ok, expected}
  end

  test "computing of next posting time fail due to incompleteness" do
    assert Posting.compute_next_posting_time_msk(Posting.new(), ~N[2020-10-10 02:02:02]) ==
             {:error, :state_incomplete}
  end

  test "computing flush count (fixed)" do
    state =
      with {:ok, x} <- Posting.new() |> Posting.put_raw_flush("6"),
           {:ok, x} <- x |> Posting.put_raw_cron("* * * * *"),
           do: x

    assert Posting.compute_flush_count(state) == {:ok, 6}
  end

  test "computing flush count (range)" do
    state =
      with {:ok, x} <- Posting.new() |> Posting.put_raw_flush("6-10"),
           {:ok, x} <- x |> Posting.put_raw_cron("* * * * *"),
           do: x

    {:ok, count} = Posting.compute_flush_count(state)

    assert count >= 6
    assert count <= 10
  end

  test "computing flush count (incomplete state)" do
    {:ok, state} = Posting.new() |> Posting.put_raw_flush("55")

    assert Posting.compute_flush_count(state) == {:error, :state_incomplete}
  end

  describe "formatting data back" do
    test "formatting cron" do
      {:ok, state} = Posting.new() |> Posting.put_raw_cron("* * * * *")
      assert Posting.format_cron(state) == {:ok, "* * * * * *"}
    end

    test "formatting flush" do
      {:ok, state} = Posting.new() |> Posting.put_raw_flush("6 - 10")
      assert Posting.format_flush(state) == {:ok, "6-10"}
    end
  end
end
