defmodule CuteFemBotTest do
  use ExUnit.Case
  doctest CuteFemBot

  test "greets the world" do
    assert CuteFemBot.hello() == :world
  end
end
