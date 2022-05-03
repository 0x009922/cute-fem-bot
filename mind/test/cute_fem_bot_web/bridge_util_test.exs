defmodule CuteFemBotWebBridgeUtilTest do
  use ExUnit.Case, async: true
  import CuteFemBotWeb.Bridge.Util

  describe "content-type extraction" do
    test "when content-type header is specified, returns its value" do
      resp = %Finch.Response{body: nil, status: 200, headers: [{"content-type", "foobar"}]}

      assert extract_content_type_header(resp) == "foobar"
    end

    test "when header is not specified, returns octet-stream" do
      resp = %Finch.Response{body: nil, status: 200, headers: []}

      assert extract_content_type_header(resp) == "application/octet-stream"
    end
  end
end
