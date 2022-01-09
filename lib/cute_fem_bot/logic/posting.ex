defmodule CuteFemBot.Logic.Posting do
  use GenServer
  require Logger

  alias CuteFemBot.Core.Suggestion

  def start_link(opts) do
    {deps, opts} = Keyword.pop!(opts, :deps)

    GenServer.start_link(__MODULE__, deps, opts)
  end

  @impl true
  def init(%{config: _, persistence: pers, api: _} = deps) do
    schedule_posting(pers, 0)

    {:ok, %{deps: deps, key: 0}}
  end

  @impl true
  def handle_cast(:reschedule, %{deps: deps, key: key}) do
    Logger.info("Reschedule signal received")
    schedule_posting(deps.persistence, key + 1)
    {:noreply, %{deps: deps, key: key + 1}}
  end

  @impl true
  def handle_info({:do_posting, key_schedule}, %{deps: deps, key: key_truth} = state) do
    if key_schedule != key_truth do
      Logger.info("Skipping posting signal due to bad scheduling key")
      {:noreply, state}
    else
      Logger.info("do_posting signal received")

      count =
        with %CuteFemBot.Core.Posting{} = posting <-
               CuteFemBot.Persistence.get_posting(deps.persistence),
             {:ok, count} <- CuteFemBot.Core.Posting.compute_flush_count(posting),
             do: count

      queue = CuteFemBot.Persistence.get_approved_queue(deps.persistence) |> Enum.take(count)
      # file_ids = queue |> Enum.map(fn {_ty, file_id} -> file_id end)
      %CuteFemBot.Config{posting_chat: chat_id} = CuteFemBot.Config.State.get(deps.config)

      Logger.debug("Posting files: #{inspect(queue)}")

      queue
      |> Enum.each(fn %Suggestion{file_id: file_id, user_id: _user_id} = suggestion ->
        %{method_name: method, body_part: body_part} = Suggestion.to_send(suggestion)

        # user = CuteFemBot.Logic.Util.user_html_link_using_meta(deps.persistence, user_id)
        # caption = "Предложка: #{user}"

        CuteFemBot.Telegram.Api.request!(deps.api,
          method_name: method,
          body:
            %{
              "chat_id" => chat_id,
              # "caption" => caption,
              "parse_mode" => "html"
            }
            |> Map.merge(body_part)
        )

        CuteFemBot.Persistence.files_posted(deps.persistence, [file_id])

        Logger.info("File #{file_id} is posted!")
      end)

      schedule_posting(deps.persistence, key_truth)

      {:noreply, state}
    end
  end

  # private

  defp schedule_posting(persistence, key) do
    case CuteFemBot.Persistence.get_posting(persistence) do
      nil ->
        Logger.info("Posting data not found in the persistence; skip posting scheduling")

      %CuteFemBot.Core.Posting{} = posting ->
        now = DateTime.utc_now() |> DateTime.to_naive()
        {:ok, fire_at} = CuteFemBot.Core.Posting.compute_next_posting_time(posting, now)
        diff_ms = NaiveDateTime.diff(fire_at, now, :millisecond)

        Logger.info("Scheduling posting at #{fire_at} (or after #{diff_ms} ms)")

        Process.send_after(self(), {:do_posting, key}, diff_ms)
    end
  end

  # Client API

  def reschedule(server) do
    GenServer.cast(server, :reschedule)
  end
end
