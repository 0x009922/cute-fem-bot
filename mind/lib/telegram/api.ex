defmodule Telegram.Api do
  require Logger

  use GenServer

  alias Telegram.Api.Config

  def start_link(opts) do
    {name, opts} = Keyword.pop!(opts, :name)
    {%Config{} = cfg, _} = Keyword.pop!(opts, :config)

    GenServer.start_link(__MODULE__, cfg, name: name)
  end

  @impl true
  def init(%Config{} = cfg) do
    {:ok, cfg}
  end

  @impl true
  def handle_call({:make_request, opts}, _from, cfg) do
    {:reply, make_request(cfg, opts), cfg}
  end

  @impl true
  def handle_cast({:make_request, opts}, cfg) do
    make_request(cfg, opts)
    {:noreply, cfg}
  end

  defp make_request(%Config{finch: finch, token: token}, opts) do
    method_name = Keyword.fetch!(opts, :method_name)
    body = Keyword.get(opts, :body, nil)

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
  defp prepare_body(body), do: Jason.encode!(body)

  defp do_request_with_retries(finch, token, method_name, request_body) do
    request_body = prepare_body(request_body)

    Logger.debug("Making request to Telegram: #{method_name}; body: #{inspect(request_body)}")

    case Finch.Request.build(
           :post,
           Telegram.Util.href_api(token, method_name),
           %{"content-type" => "application/json"},
           request_body,
           []
         )
         |> Finch.request(finch) do
      {:error, err} ->
        {:error, :http, err}

      {:ok, %Finch.Response{body: response_body}} ->
        case Jason.decode!(response_body) do
          %{"ok" => true, "result" => result} ->
            {:ok, result}

          %{"ok" => false, "parameters" => %{"retry_after" => seconds}} ->
            # retrying
            Logger.warning("Telegram told to retry request after #{seconds} seconds...")
            Process.sleep(:timer.seconds(seconds))
            do_request_with_retries(finch, token, method_name, request_body)

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

  def request_cast(api, opts) do
    GenServer.cast(api, {:make_request, opts})
  end

  def request!(api, opts) do
    case request(api, opts) do
      {:ok, response} -> response
      :error -> raise "request! failed"
    end
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
    case delete_message(api, chat_id, message_id) do
      {:ok, _} -> :ok
      :error -> raise "delete_message! failed"
    end
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
