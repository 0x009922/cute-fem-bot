defmodule CuteFemBot.Tg.Api do
  @moduledoc """
  This module is a layer to call Telegram Bot APIs.
  """

  require Logger

  alias CuteFemBot.Tg.Api.Config
  alias CuteFemBot.Tg.Types

  def get_updates(%Config{} = cfg, body \\ nil) do
    case make_request(cfg, method_name: "getUpdates", body: body) do
      {:ok, updates} -> {:ok, Enum.map(updates, &Types.Update.parse/1)}
      x -> x
    end
  end

  defp make_request(%Config{} = cfg, opts) do
    method_name = Keyword.fetch!(opts, :method_name)

    body =
      case Keyword.get(opts, :body, nil) do
        nil -> nil
        x when is_binary(x) -> x
        x -> JSON.encode!(x)
      end

    Logger.debug("Making request to Telegram: #{method_name}")

    case Finch.Request.build(
           :post,
           "https://api.telegram.org/bot#{cfg.token}/#{method_name}",
           %{"content-type" => "application/json"},
           body,
           []
         )
         |> Finch.request(cfg.finch) do
      {:error, err} ->
        Logger.error("Error occured while making request to Telegram: #{inspect(err)}")
        :error

      {:ok, %Finch.Response{body: body}} ->
        case JSON.decode!(body) do
          %{"ok" => true, "result" => result} ->
            {:ok, result}

          %{"ok" => false, "description" => desc} ->
            Logger.error("Telegram respond with an error: #{desc}")
            :error

          unknown_body ->
            Logger.error("Unable to parse Telegram response: #{inspect(unknown_body)}")
            :error
        end
    end
  end
end
