defmodule TrafficTest do
  use ExUnit.Case, async: true

  alias Traffic.Context
  alias Traffic.Builder
  alias Traffic.Point

  defmodule SetPayloadToFoo do
    @behaviour Point

    @impl true
    def handle(ctx) do
      ctx
      |> Context.assign(:payload, "foo")
    end
  end

  defmodule ConcatBar do
    @behaviour Point

    @impl true
    def handle(ctx) do
      value = ctx.assigns.payload <> "bar"

      Context.assign(ctx, :payload, value)
      |> Context.halt()
    end
  end

  defmodule SomeModule do
    use Builder

    over(:do_nothing)

    def do_nothing(x) do
      x
    end
  end

  test "runs traffic over 2 points" do
    assert {:ok, %Context{assigns: %{payload: "foobar"}}} =
             Traffic.run(Context.new(), [SetPayloadToFoo, ConcatBar])
  end

  test "halted is set to true" do
    points = [
      fn ctx -> Context.halt(ctx) end
    ]

    assert {:ok, %Context{halted: true}} = Traffic.run(Context.new(), points)
  end

  test "halted reason is set" do
    points = [
      fn ctx -> Context.halt(ctx, "just 4 fun") end
    ]

    assert {:ok, %Context{halt_reason: "just 4 fun"}} = Traffic.run(Context.new(), points)
  end

  test "errors when traffic is not halted" do
    assert {:error, {:not_halted, %Context{}}} = Traffic.run(Context.new(), [SetPayloadToFoo])
  end

  describe "complex traffic with builder" do
    defmodule ComplexTraffic do
      use Builder

      over(:intro)

      # do nothing
      over(fn %Context{} = ctx ->
        ctx
      end)

      over(&private_do_nothing/1)

      over(SomeModule)

      over(:router)

      defp private_do_nothing(ctx) do
        ctx
      end

      def intro(%Context{assigns: %{payload: payload}} = ctx) do
        direction =
          case payload do
            "go left" ->
              :left

            "go right" ->
              :right

            x ->
              ctx
              |> halt({:error, "expected left or right, got #{inspect(x)}"})
          end

        Context.assign(ctx, :direction, direction)
      end

      def router(%Context{assigns: %{direction: dir}} = ctx) do
        case dir do
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

    test "going right through complex traffic" do
      assert {:ok, %Context{assigns: %{payload: "foo"}, halted: true, halt_reason: {:ok, :right}}} =
               Traffic.run(Context.new() |> Context.assign(:payload, "go right"), [ComplexTraffic])
    end

    test "going left through complex traffic" do
      assert {:ok, %Context{halted: true, halt_reason: {:ok, :left}}} =
               Traffic.run(Context.new() |> Context.assign(:payload, "go left"), [ComplexTraffic])
    end
  end

  test "traffic errors when point doesn't return a context" do
    points = [fn _ -> :some_random_stuff end]
    ctx = Context.new() |> Context.assign(:foo, :bar)
    ctx_with_trace = %Context{ctx | trace: points}

    assert {:error, err} = Traffic.run(ctx, points)
    assert err == {:ctx_lost, ctx_with_trace, :some_random_stuff}
  end

  test "when error is raised at some point, traffic catches it" do
    points = [
      fn ctx -> Context.assign(ctx, :foo, "bar") end,
      fn _ -> raise "nya" end
    ]

    assert {:error, err} = Traffic.run(Context.new(), points)
    assert {:raised, err, _trace, %Context{} = ctx} = err
    assert ctx.assigns == %{foo: "bar"}
    assert ctx.trace == points |> Enum.reverse()
    assert err == %RuntimeError{message: "nya"}
  end

  test "when wrong point function is passed, traffic handles it as raise" do
    points = [fn -> nil end]

    assert {:error, err} = Traffic.run(Context.new(), points)
    assert {:raised, err, _trace, _ctx} = err
    assert %BadArityError{} = err
  end

  test "when point is raised within nested move_on(), it cought as raise" do
    points = [fn x -> Traffic.move_on(x, [fn _ -> raise "nya" end]) end]

    assert {:error, err} = Traffic.run(Context.new(), points)
    assert {:raised, err, _trace, _ctx} = err
    assert %RuntimeError{message: "nya"} = err
  end

  describe "conditional overs" do
    defmodule TrafficWithConditions do
      use Builder

      over_if(&check_whatever(&1, :foo), :foo)
      over_if(&check_whatever(&1, :bar), :bar)

      defp check_whatever(ctx, value) do
        case ctx do
          %Context{assigns: %{whatever: ^value}} -> true
          _ -> false
        end
      end

      def foo(ctx) do
        halt(ctx, :foo)
      end

      def bar(ctx) do
        halt(ctx, :bar)
      end
    end

    test "foo" do
      assert {:ok, %Context{halt_reason: :foo}} =
               Traffic.run(Context.new() |> Context.assign(:whatever, :foo), [
                 TrafficWithConditions
               ])
    end

    test "bar" do
      assert {:ok, %Context{halt_reason: :bar}} =
               Traffic.run(Context.new() |> Context.assign(:whatever, :bar), [
                 TrafficWithConditions
               ])
    end
  end

  describe "builder order" do
    defmodule BuilderFunsOrder do
      use Builder

      over(:init_list)
      over(&put_into_list(&1, 1))
      over(&put_into_list(&1, 2))
      over(&put_into_list(&1, 3))
      over(&halt/1)

      def init_list(ctx) do
        assign(ctx, :list, [])
      end

      defp put_into_list(ctx, value) do
        assign(ctx, :list, ctx.assigns.list ++ [value])
      end
    end

    test "order is ok" do
      assert {:ok, %Context{assigns: %{list: [1, 2, 3]}}} =
               Traffic.run(Context.new(), [BuilderFunsOrder])
    end
  end

  describe "nested builders" do
    defmodule BuilderA do
      use Builder

      over(&Function.identity/1)
    end

    defmodule BuilderB do
      use Builder

      over(BuilderA)
      over(&halt/1)
    end

    test "when one builder goes through other builder, it works" do
      assert {:ok, _} = Traffic.run(Context.new(), [BuilderB])
    end
  end
end
