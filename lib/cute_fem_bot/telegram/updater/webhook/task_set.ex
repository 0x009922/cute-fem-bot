defmodule CuteFemBot.Telegram.Updater.Webhook.TaskSet do
  use Task
  require Logger

  alias CuteFemBot.Telegram.Api

  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [Keyword.fetch!(arg, :deps)])
  end

  def run(%{api: api, config: config}) do
    case webhook_url(config) do
      {:error, :public_path_not_specified} ->
        Logger.warning("Public path is not specified; ignoring webhook setting")

      {:ok, url} ->
        Api.request!(
          api,
          method_name: "setWebhook",
          body: %{
            "url" => url
          }
        )

        Logger.info("Webhook is set successfully. URL: #{url}")
    end
  end

  defp webhook_url(config) do
    case Application.get_env(:cute_fem_bot, :public_path, nil) do
      nil ->
        {:error, :public_path_not_specified}

      url ->
        %CuteFemBot.Config{api_token: token} = CuteFemBot.Config.State.get(config)
        {:ok, "#{url}/webhook/#{token}"}
    end
  end
end
