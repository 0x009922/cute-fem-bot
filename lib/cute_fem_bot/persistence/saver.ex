defmodule CuteFemBot.Persistence.Saver do
  @filename "./data/state"

  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, Keyword.get(opts, :persistence), opts)
  end

  @impl true
  def init(persistence) do
    read_state_and_swap(persistence)
    schedule_save_job()
    {:ok, persistence}
  end

  @impl true
  def handle_call(:save, _, persistence) do
    save_state_from_memory(persistence)
    {:reply, :ok, persistence}
  end

  @impl true
  def handle_info(:save_job, pers) do
    save_state_from_memory(pers)
    schedule_save_job()
    {:noreply, pers}
  end

  # client api

  def save_immediately(saver) do
    GenServer.call(saver, :save)
  end

  # private

  defp schedule_save_job() do
    Process.send_after(self(), :save_job, :timer.seconds(15))
  end

  defp read_state_and_swap(pers) do
    case read() do
      {:ok, state} ->
        CuteFemBot.Persistence.put_state(pers, state)
        Logger.info("State is loaded from file")

      _ ->
        nil
    end
  end

  defp save_state_from_memory(pers) do
    CuteFemBot.Persistence.get_state(pers)
    |> write()

    Logger.info("State is saved")
  end

  defp read() do
    case File.read(@filename) do
      {:ok, binary} -> {:ok, :erlang.binary_to_term(binary)}
      _ -> :error
    end
  end

  defp write(state) do
    binary = :erlang.term_to_binary(state)
    File.write!(@filename, binary)
  end
end
