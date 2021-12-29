defmodule CuteFemBot.Config.State do
  @moduledoc """
  Agent with a config to access it at runtime
  """

  use Agent
  require Logger

  def start_link([%CuteFemBot.Config{} = cfg | opts]) do
    Logger.info("Starting Config State Agent")
    Agent.start_link(fn -> cfg end, opts)
  end

  def get(name) do
    Agent.get(name, fn x -> x end)
  end
end
