defmodule Telegram.Api do
  require Logger

  use GenServer

  alias Telegram.Api.Config

  @type request_result() :: {:ok, any()} | {:error, request_error()}
  @type request_error() ::
          telegram_defined_error()
          | telegram_undefined_error()
          | http_error()
  @type telegram_defined_error() :: {:telegram, String.t()}
  @type telegram_undefined_error() :: {:telegram_confusing_body, any()}
  @type http_error() :: {:http, Exception.t()}

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

  @spec make_request(Config.t(), Keyword.t()) :: request_result()
  defp make_request(%Config{finch: finch, token: token}, opts) do
    method_name = Keyword.fetch!(opts, :method_name)
    body = Keyword.get(opts, :body, nil)

    request_data = fn -> "method: #{method_name}; body: #{inspect(body)}" end

    case do_request_with_retries(finch, token, method_name, body) do
      {:ok, _} = ok ->
        ok

      {:error, kind} = source_err ->
        case kind do
          {:http, err} ->
            Logger.error(
              "HTTP Error while making request to Telegram: #{inspect(err)}; #{request_data.()}"
            )

          {:telegram, description} ->
            Logger.error("Telegram error response: #{inspect(description)}; #{request_data.()}")

          {:telegram_confusing_body, response} ->
            Logger.error("Telegram confusing response: #{inspect(response)}; #{request_data.()}")
        end

        source_err
    end
  end

  defp prepare_body(nil), do: nil
  defp prepare_body(str) when is_binary(str), do: str
  defp prepare_body(body), do: Jason.encode!(body)

  @spec do_request_with_retries(Finch.Request.t(), String.t(), String.t(), any()) ::
          request_result()
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
        {:error, {:http, err}}

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
            {:error, {:telegram, "(#{migrate}) #{desc}"}}

          %{"ok" => false, "description" => desc} ->
            {:error, {:telegram, "#{desc}"}}

          unknown_body ->
            {:error, {:telegram_confusing_body, unknown_body}}
        end
    end
  end

  # client api

  @spec request(any(), Keyword.t()) :: request_result()
  def request(api, opts) do
    GenServer.call(api, {:make_request, opts}, 60_000)
  end

  @spec request_cast(any(), Keyword.t()) :: :ok
  def request_cast(api, opts) do
    GenServer.cast(api, {:make_request, opts})
  end

  @spec request!(any(), Keyword.t()) :: any()
  def request!(api, opts) do
    case request(api, opts) do
      {:ok, response} -> response
      _ -> raise "request! failed"
    end
  end

  @spec send_message(any(), any()) :: request_result()
  def send_message(api, body) do
    request(api, method_name: "sendMessage", body: body)
  end

  @spec delete_message(any(), pos_integer(), pos_integer()) :: request_result()
  def delete_message(api, chat_id, message_id) do
    request(api,
      method_name: "deleteMessage",
      body: %{
        "chat_id" => chat_id,
        "message_id" => message_id
      }
    )
  end

  @spec delete_message!(any(), pos_integer(), pos_integer()) :: :ok
  def delete_message!(api, chat_id, message_id) do
    case delete_message(api, chat_id, message_id) do
      {:ok, _} -> :ok
      _ -> raise "delete_message! failed"
    end
  end

  @spec answer_callback_query(any(), any(), any()) :: request_result()
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
