defmodule CuteFemBot.Config.State do
  @moduledoc """
  Agent with a config to access it at runtime
  """

  use Agent
  require Logger

  def start_link([%CuteFemBot.Config{} = cfg]) do
    Logger.info("Starting Config State Agent")
    Agent.start_link(fn -> cfg end, name: __MODULE__)
  end

  def get() do
    Agent.get(__MODULE__, fn x -> x end)
  end
end
