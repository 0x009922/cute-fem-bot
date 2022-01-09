defmodule CuteFemBot.Logic.Util do
  alias CuteFemBot.Persistence

  def user_html_link_using_meta(persistence, user_id) do
    case Persistence.get_user_meta(persistence, user_id) do
      {:ok, data} ->
        CuteFemBot.Util.format_user_name(data, :html)

      :not_found ->
        link = CuteFemBot.Util.user_link(user_id)
        "<i>нет данных</i> (<a href=\"#{link}\">пермалинк</a>)"
    end
  end

  def find_particular_unban_commands_as_ids(enum_commands) do
    Stream.map(enum_commands, fn cmd_name ->
      case Regex.scan(~r{^unban_(\d+)$}, cmd_name) do
        [[_, user_id]] -> {:uid, String.to_integer(user_id)}
        _ -> :none
      end
    end)
    |> Stream.filter(fn parsed -> parsed != :none end)
    |> Stream.map(fn {:uid, id} -> id end)
    |> Enum.to_list()
  end
end
