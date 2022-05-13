defmodule Telegram.Updater.LongPolling.Poller do
  @moduledoc """
  Simple service that periodically fetches updates from Telegram
  """

  alias Telegram.Api
  alias Telegram.Updater.LongPolling
  alias LongPolling.Config
  alias LongPolling.State

  require Logger

  def start_link(%Config{} = cfg) do
    pid = spawn_link(fn -> poll_loop(cfg, %State{}) end)
    {:ok, pid}
  end

  defp poll_loop(%Config{} = cfg, %State{} = state) do
    state =
      case Api.request(
             cfg.api,
             method_name: "getUpdates",
             body: %{"offset" => compute_offset(state.greatest_known_update_id)}
           ) do
        {:ok, updates} ->
          Telegram.Dispatcher.dispatch_incoming_updates(cfg.dispatcher, updates)

          if length(updates) > 0 do
            %{"update_id" => id} = Enum.fetch!(updates, -1)
            %State{state | greatest_known_update_id: id}
          else
            state
          end

        {:error, _} ->
          Logger.warning("Polling failed with an error")
          state
      end

    Process.sleep(cfg.interval)
    poll_loop(cfg, state)
  end

  defp compute_offset(nil), do: nil

  defp compute_offset(num) do
    # tell telegram to forget all previous updates
    # https://core.telegram.org/bots/api#getupdates
    num + 1
  end
end
