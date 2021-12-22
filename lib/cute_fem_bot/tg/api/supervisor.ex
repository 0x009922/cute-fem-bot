defmodule CuteFemBot.Tg.Api.Supervisor do
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
      {Finch, name: CuteFemBot.Tg.Api.Finch},
      %{
        id: CuteFemBot.Tg.Api.Server,
        start:
          {CuteFemBot.Tg.Api.Server, :start_link,
           [
             %CuteFemBot.Tg.Api.Config{
               token: token,
               finch: CuteFemBot.Tg.Api.Finch
             }
           ]}
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
