defmodule CuteFemBotCoreScheduleEntryTest do
  use ExUnit.Case

  alias CuteFemBot.Core.Schedule.Entry

  defp factory!(cron, flush) do
    {:ok, x} = Entry.new() |> Entry.put_raw_cron(cron)
    {:ok, x} = Entry.put_raw_flush(x, flush)
    x
  end

  test "new item is incomplete" do
    assert Entry.new() |> Entry.is_complete?() == false
  end

  test "parses correct cron expression" do
    assert {:ok, _} = Entry.new() |> Entry.put_raw_cron("* * * * *")
  end

  test "parses incorrect cron expression" do
    assert {:error, err} = Entry.new() |> Entry.put_raw_cron("henno?")
    assert is_binary(err)
  end

  test "parses correct fixed flushing" do
    assert {:ok, _} = Entry.new() |> Entry.put_raw_flush("5")
  end

  test "parses correct range flushing" do
    assert {:ok, _} = Entry.new() |> Entry.put_raw_flush("1-5")
  end

  test "parses range & fixed flushing even if it contains spaces" do
    ["   123 ", "5-9   ", " 14     - 20 "]
    |> Enum.each(fn x ->
      assert {:ok, _} = Entry.new() |> Entry.put_raw_flush(x)
    end)
  end

  test "error if in range flushing right is greater than left" do
    assert {:error, :invalid_flushing} = Entry.new() |> Entry.put_raw_flush("5-3")
  end

  test "error if in range flushing something is less than 1" do
    assert {:error, :invalid_flushing} = Entry.new() |> Entry.put_raw_flush("0-5")
    assert {:error, :invalid_flushing} = Entry.new() |> Entry.put_raw_flush("-5-5")
  end

  test "error if fixed flush is less than 1" do
    assert {:error, :invalid_flushing} = Entry.new() |> Entry.put_raw_flush("0")
  end

  test "some error flushing cases" do
    [
      "1.5",
      "1.5-5.6",
      "henno?",
      "5b10"
    ]
    |> Enum.each(fn x ->
      assert {:error, :invalid_flushing} = Entry.new() |> Entry.put_raw_flush(x)
    end)
  end

  test "not complete after cron parsing" do
    {:ok, x} = Entry.new() |> Entry.put_raw_cron("* * * * *")

    assert Entry.is_complete?(x) == false
  end

  test "not complete after flush parsing" do
    {:ok, x} = Entry.new() |> Entry.put_raw_flush("5")

    assert Entry.is_complete?(x) == false
  end

  test "complete after flush & cron parsing" do
    state =
      with {:ok, x} <- Entry.new() |> Entry.put_raw_flush("5"),
           {:ok, x} <- Entry.put_raw_cron(x, "* * * * *"),
           do: x

    assert Entry.is_complete?(state) == true
  end

  test "computing next is correct by moscow" do
    {:ok, x} = Entry.new() |> Entry.put_raw_cron("30 * * * *")
    {:ok, x} = Entry.put_raw_flush(x, "5")

    now = DateTime.from_naive!(~N[2020-05-10 04:23:55], "Europe/Moscow")
    expected = DateTime.from_naive!(~N[2020-05-10 04:30:00], "Europe/Moscow")

    assert {:ok, ^expected, _} = Entry.compute_next(x, now)
  end

  test "computing next time is correct even if input time is in UTC" do
    {:ok, x} = Entry.new() |> Entry.put_raw_cron("0 10 * * *")
    {:ok, x} = Entry.put_raw_flush(x, "5")

    now = ~U[2020-05-10 05:00:00Z]
    expected = DateTime.from_naive!(~N[2020-05-10 10:00:00], "Europe/Moscow")

    assert {:ok, ^expected, _} = Entry.compute_next(x, now)
  end

  test "computing next fails due to incompleteness (no anything)" do
    assert Entry.compute_next(Entry.new(), ~N[2020-10-10 02:02:02]) ==
             {:error, :state_incomplete}
  end

  test "computing next fails due to incompleteness (no cron)" do
    {:ok, sut} = Entry.new() |> Entry.put_raw_flush("4-5")

    assert Entry.compute_next(sut, ~N[2020-10-10 02:02:02]) ==
             {:error, :state_incomplete}
  end

  test "computing next fails due to incompleteness (no flush)" do
    {:ok, sut} = Entry.new() |> Entry.put_raw_cron("* * * * *")

    assert Entry.compute_next(sut, ~N[2020-10-10 02:02:02]) ==
             {:error, :state_incomplete}
  end

  test "computing next fixed flush count is correct" do
    {:ok, x} = Entry.new() |> Entry.put_raw_flush("6")
    {:ok, x} = x |> Entry.put_raw_cron("* * * * *")

    assert {:ok, _, 6} = Entry.compute_next(x, ~N[2020-10-10 00:00:00])
  end

  test "computing next range flush count is correct" do
    {:ok, x} = Entry.new() |> Entry.put_raw_flush("6-10")
    {:ok, x} = x |> Entry.put_raw_cron("* * * * *")

    {:ok, _, count} = Entry.compute_next(x, ~N[2020-10-10 00:00:00])

    assert count in [6, 7, 8, 9, 10]
  end

  test "computing next with many items (happy path)" do
    many = [factory!("0 * * * *", "3"), factory!("15 * * *", "9")]

    assert Entry.compute_next(many, ~N[2020-01-01 12:45:00]) ==
             {:ok, DateTime.from_naive!(~N[2020-01-01 13:00:00], "Europe/Moscow"), 3}

    assert Entry.compute_next(many, ~N[2020-01-01 12:12:22]) ==
             {:ok, DateTime.from_naive!(~N[2020-01-01 12:15:00], "Europe/Moscow"), 9}
  end

  test "computing next with many items (some item is incomplete)" do
    many = [factory!("0 * * * *", "3"), Entry.new()]

    assert Entry.compute_next(many, ~N[2020-01-01 12:45:00]) ==
             {:error, :state_incomplete}
  end

  describe "formatting data back" do
    test "formatting cron" do
      {:ok, state} = Entry.new() |> Entry.put_raw_cron("* * * * *")
      assert Entry.format_cron(state) == {:ok, "* * * * * *"}
    end

    test "formatting flush" do
      {:ok, state} = Entry.new() |> Entry.put_raw_flush("6 - 10")
      assert Entry.format_flush(state) == {:ok, "6-10"}
    end
  end
end
