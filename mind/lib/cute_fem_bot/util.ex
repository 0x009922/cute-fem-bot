defmodule CuteFemBot.Util do
  def format_user_name(%{"id" => id} = user, mode, opts \\ [])
      when mode == :markdown or mode == :html do
    anonymous =
      Keyword.get(
        opts,
        :anonymous,
        case mode do
          :markdown -> "_no name_"
          :html -> "<i>no name</i>"
        end
      )

    first_name = Map.get(user, "first_name") |> nil_or_trim
    last_name = Map.get(user, "last_name") |> nil_or_trim
    username = Map.get(user, "username")

    link = user_link(id)

    name =
      case {first_name, last_name} do
        {"", ""} -> anonymous
        {a, b} -> [a, b] |> Enum.filter(fn x -> x != nil and x != "" end) |> Enum.join(" ")
      end

    name =
      case mode do
        :markdown -> "[#{name}](#{link})"
        :html -> "<a href=\"#{link}\">#{name}</a>"
      end

    case username do
      nil -> name
      x -> "#{name} (@#{x})"
    end
  end

  def user_link(id) do
    "tg://user?id=#{id}"
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

  def format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%H:%M %d.%m.%Y %Z")
  end

  def find_all_commands(%{"text" => text}) do
    case Regex.scan(~r{/(\w+)(?:@(\w+))?}, text) do
      [] ->
        %{}

      occures ->
        Stream.map(occures, fn [_whole | groups] ->
          case groups do
            [only_cmd] -> {only_cmd, nil}
            [cmd, username] -> {cmd, %{username: username}}
          end
        end)
        |> Enum.into(%{})
    end
  end

  def find_all_commands(_), do: %{}

  def escape_html(text) when is_binary(text) do
    text
    |> String.replace(~r{<}, "&lt;")
    |> String.replace(~r{>}, "&gt;")
  end

  def inspect_err_html(err) do
    inspect(err) |> escape_html()
  end

  defp nil_or_trim(nil), do: ""
  defp nil_or_trim(x) when is_binary(x), do: String.trim(x)

  def concat_msg_text(%{"text" => text, "entities" => entities}, add_text) do
    %{
      "entities" => entities,
      "text" => text <> add_text
    }
  end

  def concat_msg_text_with_exiting_formatted(src_text, src_entities, add, where \\ :after)
      when where in [:after, :before] do
    case where do
      :after ->
        {src_text <> add, src_entities}

      :before ->
        add_text_len = String.length(add)

        entities_transformed =
          Enum.map(src_entities, &Map.update!(&1, "offset", fn x -> x + add_text_len end))

        {add <> src_text, entities_transformed}
    end
  end
end
