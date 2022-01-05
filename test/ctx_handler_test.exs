defmodule ContextFallTest do
  use ExUnit.Case

  alias CtxHandler.State

  defmodule HandlerModA do
    def main() do
      [
        :gender_greeting,
        :determine_rating,
        :go_to_mod_b,
        :maybe_error,
        :return_ctx
      ]
    end

    def gender_greeting(%{gender: value} = ctx) do
      case value do
        :male -> {:cont, :sub_branch, [:greet_male], ctx}
        :female -> {:cont, :sub_branch, [:greet_female], ctx}
      end
    end

    def greet_male(ctx) do
      {:cont, Map.put(ctx, :greeting, "xy")}
    end

    def greet_female(ctx) do
      {:cont, Map.put(ctx, :greeting, "xx")}
    end

    def determine_rating(%{age: age} = ctx) do
      rating = if age < 18, do: "18-", else: "18+"
      {:cont, Map.put(ctx, :rating, rating)}
    end

    def go_to_mod_b(ctx) do
      {:cont, :sub_mod, ContextFallTest.HandlerModB, ctx}
    end

    def maybe_error(ctx) do
      case ctx do
        %{error: true} -> raise "Test error"
        _ -> :cont
      end
    end

    def return_ctx(ctx) do
      {:halt, ctx}
    end
  end

  defmodule HandlerModB do
    def main() do
      [:entry, :empty_handler]
    end

    def entry(ctx) do
      {:cont, Map.put(ctx, :mod_b_handled_too, true)}
    end

    def empty_handler(_) do
      :cont
    end
  end

  defp ctx_factory(gender, age) do
    %{gender: gender, age: age}
  end

  test "male greeting for male gender" do
    assert {:ok, %State{ctx: %{greeting: "xy"}}} =
             CtxHandler.handle(HandlerModA, ctx_factory(:male, 18))
  end

  test "female greeting for female gender" do
    assert {:ok, %State{ctx: %{greeting: "xx"}}} =
             CtxHandler.handle(HandlerModA, ctx_factory(:female, 19))
  end

  test "determines rating for age" do
    assert {:ok, %State{ctx: %{rating: "18+"}}} =
             CtxHandler.handle(HandlerModA, ctx_factory(:male, 20))
  end

  test "mod b applied to" do
    assert {:ok, %State{ctx: %{mod_b_handled_too: true}}} =
             CtxHandler.handle(HandlerModA, ctx_factory(:female, 29))
  end

  test "path is collected correctly" do
    assert {:ok, %State{path: path}} = CtxHandler.handle(HandlerModA, ctx_factory(:male, 20))

    assert path == [
             {HandlerModA, :gender_greeting},
             {HandlerModA, :greet_male},
             {HandlerModA, :determine_rating},
             {HandlerModA, :go_to_mod_b},
             {HandlerModB, :entry},
             {HandlerModB, :empty_handler},
             {HandlerModA, :maybe_error},
             {HandlerModA, :return_ctx}
           ]
  end

  test "error is raised during the handling" do
    result = CtxHandler.handle(HandlerModA, ctx_factory(:male, 20) |> Map.put(:error, true))

    assert {:error, :raised, %RuntimeError{message: "Test error"}, _trace, _state} = result
  end

  test "raised error: state contains correct path" do
    {:error, :raised, _err, _trace, %State{path: path}} =
      CtxHandler.handle(HandlerModA, ctx_factory(:male, 20) |> Map.put(:error, true))

    assert path == [
             {HandlerModA, :gender_greeting},
             {HandlerModA, :greet_male},
             {HandlerModA, :determine_rating},
             {HandlerModA, :go_to_mod_b},
             {HandlerModB, :entry},
             {HandlerModB, :empty_handler},
             {HandlerModA, :maybe_error}
           ]
  end
end
