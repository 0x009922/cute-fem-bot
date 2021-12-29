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

    body =
      case Keyword.get(opts, :body, nil) do
        nil -> nil
        x when is_binary(x) -> x
        x -> JSON.encode!(x)
      end

    %CuteFemBot.Config{api_token: token} = CuteFemBot.Config.State.get(cfg)

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

  # client api

  def request(api, opts) do
    GenServer.call(api, {:make_request, opts})
  end

  def request!(api, opts) do
    {:ok, _} = request(api, opts)
  end

  def send_message(api, body) do
    request(api, method_name: "sendMessage", body: body)
  end
end
