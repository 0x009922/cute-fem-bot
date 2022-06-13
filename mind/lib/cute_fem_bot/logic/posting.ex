defmodule CuteFemBot.Logic.Posting do
  use GenServer
  require Logger

  alias CuteFemBot.Schema.Suggestion

  def start_link(opts) do
    {deps, opts} = Keyword.pop!(opts, :deps)

    GenServer.start_link(__MODULE__, deps, opts)
  end

  @impl true
  def init(%{config: _, api: _} = deps) do
    schedule_posting(0)

    {:ok, %{deps: deps, key: 0}}
  end

  @impl true
  def handle_cast(:reschedule, %{deps: deps, key: key}) do
    Logger.info("Reschedule signal received")
    schedule_posting(key + 1)
    {:noreply, %{deps: deps, key: key + 1}}
  end

  @impl true
  def handle_info(
        {:do_posting, key_schedule, flush_count, category},
        %{deps: deps, key: key_truth} = state
      ) do
    if key_schedule != key_truth do
      Logger.info("Skipping posting signal due to bad scheduling key")
      {:noreply, state}
    else
      Logger.info("do_posting signal received")

      queue =
        CuteFemBot.Persistence.get_approved_queue(category)
        |> Enum.take(flush_count)

      # file_ids = queue |> Enum.map(fn {_ty, file_id} -> file_id end)
      %CuteFemBot.Config{posting_chat: chat_id} = CuteFemBot.Config.State.lookup!()

      Logger.debug("Posting files: #{inspect(queue)}")

      queue
      |> Enum.each(fn %Suggestion{file_id: file_id} = suggestion ->
        %{method_name: method, body_part: body_part} = Suggestion.to_telegram_send(suggestion)

        # user = CuteFemBot.Logic.Util.user_html_link_using_meta(deps.persistence, user_id)
        # caption = "Предложка: #{user}"

        Telegram.Api.request!(deps.api,
          method_name: method,
          body:
            %{
              "chat_id" => chat_id,
              # "caption" => caption,
              "parse_mode" => "html"
            }
            |> Map.merge(body_part)
        )

        CuteFemBot.Persistence.check_as_published([file_id])

        Logger.info("File #{file_id} is posted!")
      end)

      schedule_posting(key_truth)

      {:noreply, state}
    end
  end

  # private

  defp schedule_posting(key) do
    case CuteFemBot.Persistence.get_schedule() do
      nil ->
        Logger.info("Posting data not found in the persistence; skip posting scheduling")

      %CuteFemBot.Core.Schedule.Complex{} = schedule ->
        now = DateTime.utc_now()

        {:ok, fire_at, flush, category} =
          CuteFemBot.Core.Schedule.Complex.compute_next(schedule, now)

        diff_ms = DateTime.diff(fire_at, now, :millisecond)

        Logger.info("Scheduling posting at #{fire_at} (or after #{diff_ms} ms)")

        Process.send_after(self(), {:do_posting, key, flush, category}, diff_ms)
    end
  end

  # Client API

  def reschedule(server) do
    GenServer.cast(server, :reschedule)
  end
end
