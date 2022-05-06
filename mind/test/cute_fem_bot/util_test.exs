defmodule CuteFemBotUtilTest do
  use ExUnit.Case, async: true
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
      dt = ~U[2020-10-25 10:00:00.123Z] |> DateTime.shift_zone!("Europe/Moscow")

      assert format_datetime(dt) ==
               "13:00 25.10.2020 MSK"
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

  describe "Message format concatenation" do
    defp entity(offset, len, type) do
      %{
        "offset" => offset,
        "len" => len,
        "type" => type
      }
    end

    test "all is empty" do
      assert concat_msg_text_with_exiting_formatted("", [], "") == {"", []}
    end

    test "adding text after when no entities" do
      assert concat_msg_text_with_exiting_formatted("Nya...", [], "\n...hey?") ==
               {"Nya...\n...hey?", []}
    end

    test "adding text after with entities" do
      assert concat_msg_text_with_exiting_formatted("Foo", [entity(0, 2, "bold")], " Bar") ==
               {"Foo Bar", [entity(0, 2, "bold")]}
    end

    test "adding test before with entities" do
      assert concat_msg_text_with_exiting_formatted(
               "А что по форматированию?",
               [
                 %{"length" => 1, "offset" => 0, "type" => "strikethrough"},
                 %{"length" => 3, "offset" => 2, "type" => "underline"},
                 %{"length" => 2, "offset" => 6, "type" => "italic"},
                 %{"length" => 14, "offset" => 9, "type" => "bold"}
               ],
               # 17 chars
               "<b>А ничего</b>\n\n",
               :before
             ) ==
               {"<b>А ничего</b>\n\nА что по форматированию?",
                [
                  %{"length" => 1, "offset" => 17, "type" => "strikethrough"},
                  %{"length" => 3, "offset" => 19, "type" => "underline"},
                  %{"length" => 2, "offset" => 23, "type" => "italic"},
                  %{"length" => 14, "offset" => 26, "type" => "bold"}
                ]}
    end
  end

  describe "formatting changeset errors" do
    alias Ecto.Changeset

    def cast_factory(params) do
      types = %{
        age: :integer,
        rules: :boolean,
        gender: :string
      }

      {%{}, types}
      |> Changeset.cast(params, Map.keys(types))
      |> Changeset.validate_number(:age, greater_than_or_equal_to: 0)
      |> Changeset.validate_inclusion(:gender, ["male", "female"])
    end

    test "empty changeset" do
      assert format_changeset_errors(cast_factory(%{})) == %{}
    end

    test "with bad number" do
      assert format_changeset_errors(cast_factory(%{"age" => "false"})) == %{
               age: [%{msg: "is invalid", opts: %{type: :integer, validation: :cast}}]
             }
    end

    test "with bad number range" do
      assert format_changeset_errors(cast_factory(%{"age" => "-10"})) == %{
               age: [
                 %{
                   msg: "must be greater than or equal to 0",
                   opts: %{kind: :greater_than_or_equal_to, number: 0, validation: :number}
                 }
               ]
             }
    end

    test "with bad gender" do
      assert format_changeset_errors(cast_factory(%{"gender" => "helicopter"})) == %{
               gender: [
                 %{msg: "is invalid", opts: %{enum: ["male", "female"], validation: :inclusion}}
               ]
             }
    end
  end
end
