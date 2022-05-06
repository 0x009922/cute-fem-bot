defmodule CuteFemBotWeb.Bridge.Util do
  @doc """
  Extracts Content-Type from response. Returns octet-stream if type is not specified
  """
  def extract_content_type_header(%Finch.Response{} = resp) do
    [single] =
      resp.headers
      |> Stream.filter(fn {name, _} -> name == "content-type" end)
      |> Stream.map(fn {_, value} -> value end)
      |> Stream.concat(["application/octet-stream"])
      |> Enum.take(1)

    single
  end
end
