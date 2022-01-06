defmodule CuteFemBotLogicHandlerUtilTest do
  use ExUnit.Case

  alias CuteFemBot.Persistence
  import CuteFemBot.Logic.Util

  setup do
    pid = start_supervised!(Persistence)
    %{pers: pid}
  end

  test "user html link when meta exists", %{pers: pers} do
    user_data = %{"id" => 5512, "first_name" => "Nanu", "last_name" => "Oya"}

    Persistence.update_user_meta(pers, user_data)

    assert user_html_link_using_meta(pers, 5512) ==
             "<a href=\"tg://user?id=5512\">Nanu Oya</a>"
  end

  test "user html link when no meta data", %{pers: pers} do
    assert user_html_link_using_meta(pers, 999) ==
             "<i>нет данных</i> (<a href=\"tg://user?id=999\">пермалинк</a>)"
  end
end
