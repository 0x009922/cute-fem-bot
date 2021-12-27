defmodule CuteFemBot.Telegram.Api do
  use GenServer
  require Logger
  alias CuteFemBot.Telegram.Api.Context

  @impl true
  def init(%Context{} = ctx) do
    {:ok, ctx}
  end

  @impl true
  def handle_call({:make_request, opts}, _from, ctx) do
    {:reply, make_request(ctx, opts), ctx}
  end

  def request(api, opts) do
    GenServer.call(api, {:make_request, opts})
  end

  def send_message(api, body) do
    request(api, method_name: "sendMessage", body: body)
  end

  defp make_request(%Context{token: token, finch: finch}, opts) do
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
           "https://api.telegram.org/bot#{token}/#{method_name}",
           %{"content-type" => "application/json"},
           body,
           []
         )
         |> Finch.request(finch) do
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
