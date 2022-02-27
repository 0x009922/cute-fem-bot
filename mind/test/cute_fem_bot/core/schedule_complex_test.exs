defmodule CuteFemBotCoreScheduleComplexTest do
  use ExUnit.Case

  alias CuteFemBot.Core.Schedule.Complex, as: Sut

  test "constructs from raw" do
    assert {:ok, _} =
             Sut.from_raw("""
             sfw;6-10;0 12-19 * * *
             sfw;1;0,5,10,15 * * *
             nsfw;5;0 0-7 * * *
             """)
  end

  test "not constructs from raw if bad category" do
    assert {:error, _} = Sut.from_raw("bad_cat;1;*")
  end

  test "not constructs from raw if bad cron" do
    assert {:error, _} =
             Sut.from_raw("""
             sfw;1;bad
             nsfw;2;*
             """)
  end

  test "not constructs from raw if bad flush" do
    assert {:error, _} =
             Sut.from_raw("""
             nsfw;2;*
             sfw;...;*
             """)
  end

  test "format is pretty" do
    {:ok, sut} =
      Sut.from_raw("""
      sfw;2-4;0 12-20

      sfw;4;15 14,16
      """)

    {:ok, formatted} = Sut.format(sut)

    assert formatted ==
             """
             SFW
             0 12-20 * * * * \\ 2-4
             15 14,16 * * * * \\ 4

             NSFW
             no data
             """
             |> String.trim()
  end

  test "a few next fires are correct" do
    raw = """
    nsfw;3;10,20 2,3,4 * * *
    nsfw;1;30 7 * * *
    sfw;5;15,30 14-15 * * *
    sfw;1;20 12,13,22
    """

    start = ~N[2020-01-01 00:00:00] |> DateTime.from_naive!("Europe/Moscow")

    {:ok, sut} = Sut.from_raw(raw)

    {entries, _} =
      Enum.map_reduce(1..14, start, fn _, timestamp ->
        {:ok, time, flush, category} = Sut.compute_next(sut, timestamp)
        {{time |> DateTime.to_naive(), flush, category}, DateTime.add(time, 30, :second)}
      end)

    assert entries == [
             {~N[2020-01-01 02:10:00], 3, :nsfw},
             {~N[2020-01-01 02:20:00], 3, :nsfw},
             {~N[2020-01-01 03:10:00], 3, :nsfw},
             {~N[2020-01-01 03:20:00], 3, :nsfw},
             {~N[2020-01-01 04:10:00], 3, :nsfw},
             {~N[2020-01-01 04:20:00], 3, :nsfw},
             {~N[2020-01-01 07:30:00], 1, :nsfw},
             {~N[2020-01-01 12:20:00], 1, :sfw},
             {~N[2020-01-01 13:20:00], 1, :sfw},
             {~N[2020-01-01 14:15:00], 5, :sfw},
             {~N[2020-01-01 14:30:00], 5, :sfw},
             {~N[2020-01-01 15:15:00], 5, :sfw},
             {~N[2020-01-01 15:30:00], 5, :sfw},
             {~N[2020-01-01 22:20:00], 1, :sfw}
           ]
  end
end
