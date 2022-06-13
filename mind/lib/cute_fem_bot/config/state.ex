defmodule CuteFemBot.Config.State do
  @moduledoc """
  Configuration state singleton.

  GenServer starts, reads configuration and puts it into ETS under `CuteFemBot.Config.State` name.
  When configuration is looked up, it is done fast via ETS. When reload request is accepted, it is updated from
  within the server. It is protected from outside writings.

  ## Example

      iex> {:ok, _pid} = CuteFemBot.Config.State.start_link([])
      iex> %CuteFemBot.Config{} = CuteFemBot.Config.State.lookup!()
      iex> :ok = CuteFemBot.Config.State.reload_config()

  """

  use GenServer

  def start_link([]) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    unless :ets.info(__MODULE__) == :undefined do
      raise "Config ETS table is already initialized. Call reload_config/0 instead."
    end

    cfg =
      case CuteFemBot.Config.read_cfg() do
        {:ok, cfg} -> cfg
        {:error, reason} -> raise "Failed to read cfg: #{inspect(reason)}"
      end

    :ets.new(__MODULE__, [:named_table, :protected, :set])
    :ets.insert(__MODULE__, {:state, cfg})

    IO.puts("init done")

    {:ok, nil}
  end

  def handle_call(:reload_config, _from, _state) do
    case CuteFemBot.Config.read_cfg() do
      {:ok, cfg} ->
        case :ets.insert(__MODULE__, {:state, cfg}) do
          true -> :ok
        end

      {:error, _} = err ->
        err
    end

    {:reply, :ok, nil}
  end

  def reload_config() do
    GenServer.call(__MODULE__, :reload_config)
  end

  @spec lookup!() :: CuteFemBot.Config.t()
  def lookup!() do
    case :ets.lookup(__MODULE__, :state) do
      [{:state, %CuteFemBot.Config{} = cfg}] -> cfg
      x -> raise "Failed to lookup state: #{inspect(x)}"
    end
  end
end
