defmodule CuteFemBot.Telegram.Api.Supervisor do
  @moduledoc """
  Supervisor for Telegram API server
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init([%CuteFemBot.Config{api_token: token}]) do
    children = [
      {
        Finch,
        name: CuteFemBot.Telegram.Api.Finch
      },
      {
        CuteFemBot.Telegram.Api,
        name: CuteFemBot.Telegram.Api,
        ctx: %CuteFemBot.Telegram.Api.Context{
          token: token,
          finch: CuteFemBot.Tg.Api.Finch
        }
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
