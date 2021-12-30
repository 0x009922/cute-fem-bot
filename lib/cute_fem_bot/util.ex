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

  def parse_command(raw) do
    case Regex.scan(~r{^/(\w+)(?:@(\w+))?$}, raw) do
      [[_ | groups]] ->
        case groups do
          [cmd] -> %{cmd: cmd}
          [cmd, username] -> %{cmd: cmd, username: username}
        end

      _ ->
        :error
    end
  end

  def format_datetime(%NaiveDateTime{} = dt) do
    Calendar.strftime(dt, "%d.%m.%Y %H:%M")
  end

  defp nil_or_trim(nil), do: ""
  defp nil_or_trim(x) when is_binary(x), do: String.trim(x)
end
