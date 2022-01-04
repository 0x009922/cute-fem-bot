defmodule CuteFemBotUtilTest do
  use ExUnit.Case
  import CuteFemBot.Util

  describe "format_user_name" do
    test "(markdown) user only with id and first name" do
      assert format_user_name(%{"id" => 123, "first_name" => "test"}, :markdown) ==
               "[test](tg://user?id=123)"
    end

    test "(markdown) user with empty first name" do
      assert format_user_name(%{"id" => 0, "first_name" => "   "}, :markdown,
               anonymous: "_без имени_"
             ) ==
               "[_без имени_](tg://user?id=0)"
    end

    test "markdown anonymous fallback" do
      assert format_user_name(%{"id" => 0, "first_name" => " "}, :markdown) =~ "_no name_"
    end

    test "(html) user only with id and first name" do
      assert format_user_name(%{"id" => 123, "first_name" => "God"}, :html) ==
               "<a href=\"tg://user?id=123\">God</a>"
    end

    test "(html) user with empty first name" do
      assert format_user_name(%{"id" => 0, "first_name" => "   "}, :html,
               anonymous: "<i>без имени</i>"
             ) ==
               "<a href=\"tg://user?id=0\"><i>без имени</i></a>"
    end

    test "html anonymous fallback" do
      assert format_user_name(%{"id" => 0, "first_name" => " "}, :html) =~ "<i>no name</i>"
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

  describe "find_all_commands" do
    test "single command in the text" do
      assert find_all_commands(%{"text" => "/start"}) == %{"start" => nil}
    end

    test "text contains multiple commands" do
      assert find_all_commands(%{"text" => "Hey, /cancel and /set!"}) == %{
               "cancel" => nil,
               "set" => nil
             }
    end

    test "command contains bot username" do
      assert find_all_commands(%{"text" => "/schedule@CuteFemBot"}) == %{
               "schedule" => %{username: "CuteFemBot"}
             }
    end

    test "message doesn't contain anything" do
      assert find_all_commands(%{"text" => ""}) == %{}
    end
  end

  describe "HTML escaping" do
    test "escapes" do
      assert escape_html("<h1>") == "&lt;h1&gt;"
    end
  end
end
