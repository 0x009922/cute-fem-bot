defmodule TrafficTest do
  use ExUnit.Case, async: true

  alias Traffic.Context
  alias Traffic.Builder
  alias Traffic.Point

  defmodule SetPayloadToFoo do
    @behaviour Point

    @impl true
    def treat(ctx) do
      ctx
      |> Context.set_payload("foo")
    end
  end

  defmodule ConcatBar do
    @behaviour Point

    @impl true
    def treat(ctx) do
      value = ctx.payload <> "bar"

      Context.set_payload(ctx, value)
      |> Context.halt()
    end
  end

  defmodule ComplexTraffic do
    use Builder

    over(:intro)
    over(:router)

    def intro(%Context{} = ctx) do
      case ctx.payload do
        "go left" ->
          ctx |> set_payload(:left)

        "go right" ->
          ctx |> set_payload(:right)

        x ->
          ctx
          |> halt({:error, "expected left or right, got #{inspect(x)}"})
      end
    end

    def router(%Context{} = ctx) do
      case ctx.payload do
        :left ->
          Traffic.move_on(ctx, [&over_left/1])

        :right ->
          Traffic.move_on(ctx, [SetPayloadToFoo, &over_right/1])
      end
    end

    defp over_left(ctx) do
      ctx |> halt({:ok, :left})
    end

    defp over_right(ctx) do
      ctx |> halt({:ok, :right})
    end
  end

  test "runs traffic over 2 points" do
    assert {:ok, %Context{payload: "foobar"}} =
             Traffic.run(Context.with_payload(nil), [SetPayloadToFoo, ConcatBar])
  end

  test "halted is set to true" do
    points = [
      fn ctx -> Context.halt(ctx) end
    ]

    assert {:ok, %Context{halted: true}} = Traffic.run(Context.with_payload(nil), points)
  end

  test "halted reason is set" do
    points = [
      fn ctx -> Context.halt(ctx, "just 4 fun") end
    ]

    assert {:ok, %Context{halt_payload: "just 4 fun"}} =
             Traffic.run(Context.with_payload(nil), points)
  end

  test "errors when traffic is not halted" do
    assert Traffic.run(Context.with_payload(nil), [SetPayloadToFoo]) ==
             {:error, :not_halted}
  end

  test "going right through complex traffic" do
    assert {:ok, %Context{payload: "foo", halted: true, halt_payload: {:ok, :right}}} =
             Traffic.run(Context.with_payload("go right"), [ComplexTraffic])
  end

  test "going left through complex traffic" do
    assert {:ok, %Context{payload: :left, halted: true, halt_payload: {:ok, :left}}} =
             Traffic.run(Context.with_payload("go left"), [ComplexTraffic])
  end
end
