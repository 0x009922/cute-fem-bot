defmodule CuteFemBotCorePaginationParamsTest do
  use ExUnit.Case

  alias CuteFemBot.Core.Pagination.Params, as: Sut

  describe "constructing from raw query" do
    defp parse(q, page_size) do
      Sut.from_raw_query(q, page_size)
    end

    test "empty query" do
      assert {:ok, sut} = parse(%{}, 10)
      assert sut.page == 1
      assert sut.page_size == 10
    end

    test "query with page" do
      assert {:ok, sut} = parse(%{"page" => "19"}, 10)
      assert sut.page == 19
    end

    test "query with bad page" do
      assert {:error, err} = parse(%{"page" => "yo"}, 1)
      assert err =~ ~r{invalid page}
      assert err =~ ~r{bad integer: yo}
    end

    test "query with page size" do
      assert {:ok, sut} = parse(%{"page_size" => "100"}, 9)
      assert sut.page_size == 100
    end

    test "query with bad page size" do
      assert {:error, err} = parse(%{"page_size" => "bad"}, 9)
      assert err =~ ~r{invalid page size}
      assert err =~ ~r{bad integer: bad}
    end
  end
end
