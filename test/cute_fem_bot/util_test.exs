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
end
