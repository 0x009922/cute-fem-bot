defmodule CuteFemBotLogicHandlerUtilTest do
  use ExUnit.Case
  @moduletag :integration

  alias CuteFemBot.Persistence
  import CuteFemBot.Logic.Util

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(CuteFemBot.Repo)
  end

  test "user html link when meta exists" do
    user_data = %{"id" => 5512, "first_name" => "Nanu", "last_name" => "Oya"}

    Persistence.update_user_meta(user_data)

    assert user_html_link_using_meta(5512) ==
             "<a href=\"tg://user?id=5512\">Nanu Oya</a>"
  end

  test "user html link when no meta data" do
    assert user_html_link_using_meta(999) ==
             "<i>нет данных</i> (<a href=\"tg://user?id=999\">пермалинк</a>)"
  end
end
