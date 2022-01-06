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
end
