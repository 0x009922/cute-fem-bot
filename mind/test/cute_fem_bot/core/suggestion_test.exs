defmodule CuteFemBotCoreSuggestionTest do
  use ExUnit.Case, async: true

  alias CuteFemBot.Core.Suggestion

  describe "extract_from_message()" do
    test "when there are multiple photo_size items, the biggest is extracted" do
      message = %{
        "from" => %{"id" => 123},
        "photo" => [
          %{"file_id" => "smallest", "file_size" => 500},
          %{"file_id" => "biggest", "file_size" => 10_000},
          %{"file_id" => "medium", "file_size" => 3_000}
        ]
      }

      assert {:ok, item} = Suggestion.extract_from_message(message)
      assert item.file_id == "biggest"
    end

    test "mime type is extracted from a document" do
      message = %{
        "from" => %{"id" => 123},
        "document" => %{
          "file_id" => "test",
          "mime_type" => "video/mpeg4"
        }
      }

      assert {:ok, item} = Suggestion.extract_from_message(message)
      assert item.mime_type == "video/mpeg4"
    end

    test "mime type is extracted from a video" do
      message = %{
        "from" => %{"id" => 123},
        "video" => %{
          "file_id" => "test",
          "mime_type" => "video/mp4"
        }
      }

      assert {:ok, item} = Suggestion.extract_from_message(message)
      assert item.mime_type == "video/mp4"
    end
  end
end
