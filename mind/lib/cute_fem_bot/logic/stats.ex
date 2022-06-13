defmodule CuteFemBot.Logic.Stats do
  defmodule State do
    use TypedStruct
    alias __MODULE__, as: Self
    alias Telegram.Api
    alias Telegram.Types.Message
    alias CuteFemBot.Config

    typedstruct do
      field(:banned_actions, map(), default: %{})
    end

    def report(%Self{} = self, tg) do
      %Config{master: chat_id} = Config.State.lookup!()

      {:ok, _} =
        Api.send_message(
          tg,
          Message.with_text("""
          Держи статистику:

          <b>Действия забаненных пользователей</b>
          #{format_banned(self)}
          """)
          |> Message.set_chat_id(chat_id)
        )
    end

    defp format_banned(%Self{banned_actions: data}) do
      case Map.to_list(data) do
        [] ->
          "Нет данных"

        data ->
          data
          |> Enum.map(fn {id, count} -> "#{id}: #{count}" end)
          |> Enum.join("\n")
      end
    end
  end

  alias __MODULE__, as: Self
  import Crontab.CronExpression
  require Logger

  @report_cron ~e[0 22]
  @report_tz "Europe/Moscow"

  use GenServer

  def start_link(opts) do
    GenServer.start_link(Self, Keyword.fetch!(opts, :deps), name: Self)
  end

  @impl true
  def init(deps) do
    schedule_report()

    {:ok, {%State{}, deps}}
  end

  @impl true
  def handle_cast({:inc_banned, user_id}, {%State{} = state, deps}) do
    new_banned =
      Map.put(state.banned_actions, user_id, Map.get(state.banned_actions, user_id, 0) + 1)

    {:noreply, {%State{state | banned_actions: new_banned}, deps}}
  end

  @impl true
  def handle_info(:do_report, {%State{} = state, deps}) do
    State.report(state, deps.telegram)

    # continuing with a new state
    {:noreply, {%State{}, deps}}
  end

  defp schedule_report() do
    now = DateTime.utc_now()

    report_at =
      Crontab.Scheduler.get_next_run_date!(
        @report_cron,
        now |> DateTime.shift_zone!(@report_tz) |> DateTime.to_naive()
      )
      |> DateTime.from_naive!(@report_tz)

    diff_ms = DateTime.diff(report_at, now, :millisecond)

    Logger.info("Next report will be at: #{report_at} (after #{diff_ms} ms)")

    Process.send_after(self(), :do_report, diff_ms)
  end

  # Client API

  def banned_user_acted(user_id) do
    GenServer.cast(Self, {:inc_banned, user_id})
  end
end
