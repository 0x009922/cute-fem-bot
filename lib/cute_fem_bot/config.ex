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
    field(:long_polling_interval, pos_integer(), default: 1500)
  end

  @doc """
  Reads configuration from ENV & `config.yml`
  """
  @spec read_cfg() :: {:error, any()} | {:ok, __MODULE__.t()}
  def read_cfg() do
    with {:ok, cwd} <- File.cwd(),
         {:ok, parsed} <- YamlElixir.read_all_from_file(Path.join(cwd, "config.yml")),
         {:ok, parsed} <-
           (case parsed do
              [x] -> {:ok, x}
              _ -> {:error, "Bad config"}
            end) do
      case extract_cfg(parsed) do
        %__MODULE__{} = cfg -> {:ok, cfg}
      end
    end
  end

  defp extract_cfg(raw) do
    %__MODULE__{
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
      long_polling_interval: Map.get(raw, "long_polling_interval", 1500) |> normalize_str_to_num()
    }
  end

  defp normalize_str_to_num(num) when is_integer(num), do: num
  defp normalize_str_to_num(str) when is_binary(str), do: String.to_integer(str)
end
