defmodule ContextFallTest do
  defmodule HandlerModA do
    def main() do
      [
        :gender_greeting,
        :determine_rating,
        :return_ctx
      ]
    end

    def gender_greeting(%{gender: value} = ctx) do
      case value do
        :male -> {:insert_branch, [:greet_male, :determine_rating], ctx}
        :female -> {:insert_Branch, [:greet_female, :determine_rating], ctx}
      end
    end

    def greet_male(ctx) do
      {:cont, Map.put(ctx, :greeting, "xx")}
    end

    def greet_femail(ctx) do
      {:cont, Map.put(ctx, :greeting, "xy")}
    end

    def determine_rating(%{age: age} = ctx) do
      rating = if age < 18, do: "18-", else: "18+"
      {:cont, Map.put(ctx, :rating, rating)}
    end

    def return_ctx(ctx) do
      {:halt, ctx}
    end
  end
end
