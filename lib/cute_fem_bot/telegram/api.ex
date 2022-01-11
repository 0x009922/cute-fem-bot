defmodule CuteFemBot.Telegram.Api do
  use GenServer
  require Logger
  alias CuteFemBot.Telegram.Api.Context

  def start_link(opts) do
    {%Context{} = ctx, opts} = Keyword.pop!(opts, :ctx)

    GenServer.start_link(__MODULE__, ctx, opts)
  end

  @impl true
  def init(%Context{} = ctx) do
    {:ok, ctx}
  end

  @impl true
  def handle_call({:make_request, opts}, _from, ctx) do
    {:reply, make_request(ctx, opts), ctx}
  end

  defp make_request(%Context{finch: finch, config: cfg}, opts) do
    method_name = Keyword.fetch!(opts, :method_name)
    body = Keyword.get(opts, :body, nil)
    %CuteFemBot.Config{api_token: token} = CuteFemBot.Config.State.lookup!(cfg)

    request_data = fn -> "method: #{method_name}; body: #{inspect(body)}" end

    case do_request_with_retries(finch, token, method_name, body) do
      {:ok, _} = ok ->
        ok

      {:error, :http, err} ->
        Logger.error(
          "HTTP Error while making request to Telegram: #{inspect(err)}; #{request_data.()}"
        )

        :error

      {:error, :telegram, description} ->
        Logger.error("Telegram error response: #{inspect(description)}; #{request_data.()}")
        :error

      {:error, :telegram_unknown, response} ->
        Logger.error("Telegram confusing response: #{inspect(response)}; #{request_data.()}")
        :error
    end
  end

  defp prepare_body(nil), do: nil
  defp prepare_body(str) when is_binary(str), do: str
  defp prepare_body(body), do: JSON.encode!(body)

  defp do_request_with_retries(finch, token, method_name, body) do
    body = prepare_body(body)

    Logger.debug("Making request to Telegram: #{method_name}; body: #{inspect(body)}")

    case Finch.Request.build(
           :post,
           "https://api.telegram.org/bot#{token}/#{method_name}",
           %{"content-type" => "application/json"},
           body,
           []
         )
         |> Finch.request(finch) do
      {:error, err} ->
        {:error, :http, err}

      {:ok, %Finch.Response{body: body}} ->
        case JSON.decode!(body) do
          %{"ok" => true, "result" => result} ->
            {:ok, result}

          %{"ok" => false, "parameters" => %{"retry_after" => seconds}} ->
            # retrying
            Logger.warning("Telegram told to retry request after #{seconds} seconds...")
            Process.sleep(:timer.seconds(seconds))
            do_request_with_retries(finch, token, method_name, body)

          %{
            "ok" => false,
            "description" => desc,
            "parameters" => %{"migrate_to_chat_id" => migrate}
          } ->
            {:error, :telegram, "(#{migrate}) #{desc}"}

          %{"ok" => false, "description" => desc} ->
            {:error, :telegram, desc}

          unknown_body ->
            {:error, :telegram_unknown, unknown_body}
        end
    end
  end

  # client api

  def request(api, opts) do
    GenServer.call(api, {:make_request, opts}, 60_000)
  end

  def request!(api, opts) do
    {:ok, response} = request(api, opts)
    response
  end

  def send_message(api, body) do
    request(api, method_name: "sendMessage", body: body)
  end

  def delete_message(api, chat_id, message_id) do
    request(api,
      method_name: "deleteMessage",
      body: %{
        "chat_id" => chat_id,
        "message_id" => message_id
      }
    )
  end

  def delete_message!(api, chat_id, message_id) do
    {:ok, _} = delete_message(api, chat_id, message_id)
  end

  def answer_callback_query(api, query_id, _opts \\ []) do
    request(
      api,
      method_name: "answerCallbackQuery",
      body: %{
        "callback_query_id" => query_id
      }
    )
  end
end
