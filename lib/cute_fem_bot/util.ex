defmodule CuteFemBot.Util do
  def format_user_name(user, anonymous_fallback \\ "<no name>") do
    %{"id" => id} = user

    first_name = Map.get(user, "first_name") |> nil_or_trim
    last_name = Map.get(user, "last_name") |> nil_or_trim
    username = Map.get(user, "username")

    name =
      case {first_name, last_name} do
        {"", ""} -> anonymous_fallback
        {a, b} -> [a, b] |> Enum.filter(fn x -> x != nil and x != "" end) |> Enum.join(" ")
      end

    name_with_id = "[#{name}](tg://user?id=#{id})"

    case username do
      nil -> name_with_id
      x -> "#{name_with_id} (@#{x})"
    end
  end

  def nil_or_trim(nil), do: ""
  def nil_or_trim(x) when is_binary(x), do: String.trim(x)
end
