defmodule CuteFemBot.Telegram.Api.Supervisor do
  @moduledoc """
  Supervisor for Telegram API server
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    children = [
      {
        Finch,
        name: CuteFemBot.Telegram.Api.Finch
      },
      {
        CuteFemBot.Telegram.Api,
        name: Keyword.get(opts, :api),
        ctx: %CuteFemBot.Telegram.Api.Context{
          finch: CuteFemBot.Telegram.Api.Finch,
          config: Keyword.fetch!(opts, :config)
        }
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
