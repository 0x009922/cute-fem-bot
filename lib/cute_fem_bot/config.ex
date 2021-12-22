defmodule CuteFemBot.Config do
  @moduledoc """
  A struct that represents CuteFemBot configuration
  """

  use TypedStruct

  typedstruct do
    @typedoc "CuteFemBot cfg"

    field(:api_token, String.t(), enforce: true)
  end

  def read_cfg() do
    path = Path.join(File.cwd!(), "config.yml")

    case YamlElixir.read_all_from_file(path) do
      {:error, err} ->
        {:error, err}

      {
        :ok,
        [
          %{
            "api_token" => token
          }
        ]
      } ->
        {:ok, %__MODULE__{api_token: token}}

      {:ok, _} ->
        {:error, "Bad config"}
    end
  end
end
