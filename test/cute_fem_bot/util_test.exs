defmodule CuteFemBotUtilTest do
  use ExUnit.Case
  import CuteFemBot.Util

  describe "format_user_name" do
    test "user only with id and first name" do
      assert format_user_name(%{"id" => 123, "first_name" => "test"}) ==
               "[test](tg://user?id=123)"
    end

    test "user with empty first name" do
      assert format_user_name(%{"id" => 00, "first_name" => "   "}, "empty") ==
               "[empty](tg://user?id=0)"
    end
  end

  describe "parse_command" do
    test "cmd without mention" do
      assert parse_command("/start") == %{cmd: "start"}
    end

    test "cmd with mention" do
      assert parse_command("/test@username") == %{cmd: "test", username: "username"}
    end
  end

  describe "format_datetime" do
    test "formats" do
      assert format_datetime(~N[2020-10-25 10:00:00.123]) == "25.10.2020 10:00"
    end
  end
end
