defmodule CuteFemBotWebControllerSuggestionsTest do
  use ExUnit.Case, async: true
  import CuteFemBotWeb.Controllers.Suggestions, only: [parse_decision: 1]

  describe "parsing decision" do
    test "ok data" do
      ~w(sfw nsfw reject)
      |> Enum.each(fn value ->
        assert parse_decision(%{"decision" => value}) == {:ok, String.to_existing_atom(value)}
      end)
    end

    test "not ok data" do
      ~w(not ok)
      |> Enum.each(fn value ->
        assert {:error, _} = parse_decision(%{"decision" => value})
      end)
    end
  end
end
