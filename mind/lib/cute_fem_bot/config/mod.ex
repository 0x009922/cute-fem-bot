defmodule CuteFemBot.Config do
  @moduledoc """
  A struct that represents CuteFemBot configuration
  """

  use TypedStruct

  typedstruct do
    @typedoc """
    CuteFemBot cfg

    `admins` is a list of IDs of users that are allowed to control
    schedule, queue, banlist etc

    `master` is an ID of super user, e.g. for debugging

    `suggestions_chat` is an ID of the chat where bot will send
    users' suggestions to
    """

    field(:api_token, String.t(), enforce: true)
    field(:master, integer() | String.t(), enforce: true)
    field(:admins, list(integer() | String.t()), enforce: true)
    field(:suggestions_chat, integer() | String.t(), enforce: true)
    field(:posting_chat, any(), enforce: true)
    field(:port, integer(), default: nil)
    field(:updates_approach, :long_polling | :webhook, default: :long_polling)
    field(:long_polling_interval, pos_integer(), default: 4000)
    field(:www_path, String.t(), default: nil)
  end

  @doc """
  Reads configuration from file.

  File path is specified via config, e.g.

  ```
  config :cute_fem_bot, CuteFemBot.Config,
    path: "data/config.yaml"
  ```
  """
  @spec read_cfg() :: {:error, any()} | {:ok, __MODULE__.t()}
  def read_cfg() do
    with {:ok, env} <- try_fetch_env(),
         {:ok, path} <- try_get_file_path_from_env(env),
         {:ok, raw_yaml} <- YamlElixir.read_all_from_file(path),
         {:ok, parsed} <- extract_cfg(raw_yaml) do
      {:ok, parsed}
    end
  end

  defp try_fetch_env() do
    case Application.fetch_env(:cute_fem_bot, __MODULE__) do
      :error -> {:error, "Configure #{inspect(__MODULE__)} first"}
      ok -> ok
    end
  end

  defp try_get_file_path_from_env(env) when is_list(env) do
    case Keyword.fetch(env, :path) do
      :error -> {:error, ":path key is not found in the config"}
      ok -> ok
    end
  end

  defp extract_cfg([raw]) when is_map(raw) do
    cfg = %__MODULE__{
      api_token: Map.fetch!(raw, "api_token"),
      master: Map.fetch!(raw, "master"),
      admins: Map.fetch!(raw, "admins"),
      suggestions_chat: Map.fetch!(raw, "suggestions_chat"),
      posting_chat: Map.fetch!(raw, "posting_chat"),
      port: Map.get(raw, "port", 3000) |> normalize_str_to_num,
      updates_approach:
        case Map.get(raw, "updates_approach", "long_polling") do
          "long_polling" -> :long_polling
          "webhook" -> :webhook
        end,
      long_polling_interval:
        Map.get(raw, "long_polling_interval", 1500) |> normalize_str_to_num(),
      www_path: Map.get(raw, "www_path")
    }

    {:ok, cfg}
  end

  defp extract_cfg(x) do
    {:error, "Failed to parse config: #{inspect(x)}"}
  end

  defp normalize_str_to_num(num) when is_integer(num), do: num
  defp normalize_str_to_num(str) when is_binary(str), do: String.to_integer(str)
end
