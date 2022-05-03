defmodule CuteFemBotWebBridgeSuggestionsParamsTest do
  use ExUnit.Case, async: true
  alias CuteFemBotWeb.Bridge.IndexSuggestionsParams, as: Params

  describe "from raw query" do
    test "when query is empty" do
      assert {:ok, params} = Params.from_raw_query(%{})
      assert params.published == :whatever
      assert params.decision == :whatever
    end

    test "published=true" do
      assert {:ok, params} = Params.from_raw_query(%{"published" => "true"})
      assert params.published == true
    end

    test "published=false" do
      assert {:ok, params} = Params.from_raw_query(%{"published" => "false"})
      assert params.published == false
    end

    test "published=<invalid>" do
      assert {:error, _} = Params.from_raw_query(%{"published" => "whatever"})
    end

    test "decision=none" do
      assert {:ok, %Params{decision: nil}} = Params.from_raw_query(%{"decision" => "none"})
    end

    test "decision=sfw" do
      assert {:ok, %Params{decision: :sfw}} = Params.from_raw_query(%{"decision" => "sfw"})
    end

    test "decision=nsfw" do
      assert {:ok, %Params{decision: :nsfw}} = Params.from_raw_query(%{"decision" => "nsfw"})
    end

    test "decision=whatever" do
      assert {:ok, %Params{decision: :whatever}} =
               Params.from_raw_query(%{"decision" => "whatever"})
    end

    test "decision=<invalid>" do
      assert {:error, _} = Params.from_raw_query(%{"decision" => "51235"})
    end
  end
end
