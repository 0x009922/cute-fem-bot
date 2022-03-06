defmodule CuteFemBotWeb.Auth do
  @moduledoc """
  Server that allocates access keys for admins to
  access to web
  """

  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, Keyword.fetch!(opts, :name), opts)
  end

  def create_key(name, user_id, ttl \\ 60 * 60) when ttl > 0 do
    GenServer.call(name, {:create, user_id, ttl})
  end

  def lookup(name, key) do
    case :ets.match(name, {:"$1", key, :"$2"}) do
      [] -> nil
      [[user_id, expires_at]] -> {user_id, expires_at}
    end
  end

  @impl true
  def init(table) do
    keys = :ets.new(table, [:named_table, read_concurrency: true])

    {:ok, keys}
  end

  @impl true
  def handle_call({:create, user_id, ttl}, _, keys) do
    key = gen_uuid(keys)
    expires_at = compute_expiration_datetime(ttl)
    :ets.insert(keys, {user_id, key, expires_at})

    Logger.info(
      "Key for user #{user_id} is created. Time to live: #{ttl}s, or until #{expires_at}"
    )

    schedule_expiration(user_id, ttl)

    {:reply, {:ok, key, expires_at}, keys}
  end

  @impl true
  def handle_info({:expire, user_id}, keys) do
    case :ets.lookup(keys, user_id) do
      [] ->
        Logger.debug("Tried to expire key for user #{user_id}, but there is no entry")

      [{_user_id, _key, expire_at}] ->
        if is_key_expired?(expire_at) do
          :ets.delete(keys, user_id)
          Logger.info("Key for user #{user_id} is expired")
        else
          Logger.debug("Key for user #{user_id} is not expired yet")
        end
    end

    {:noreply, keys}
  end

  defp compute_expiration_datetime(ttl) do
    DateTime.utc_now()
    |> DateTime.add(ttl)
  end

  defp is_key_expired?(expire_at) do
    DateTime.compare(DateTime.utc_now(), expire_at) == :gt
  end

  defp gen_uuid(keys) do
    id = UUID.uuid4(:hex)

    case lookup(keys, id) do
      nil -> id
      _ -> gen_uuid(keys)
    end
  end

  defp schedule_expiration(user_id, ttl) do
    Process.send_after(self(), {:expire, user_id}, :timer.seconds(ttl))
  end
end
