defmodule CuteFemBot.Logic.Handler.Middleware.Message.Moderation do
  @moduledoc """
  Implying that if context enters this module it means that message from moderation for sure
  """

  alias CuteFemBot.Core.Posting

  def main() do
    [
      :fetch_chat_state,
      :handle_message
    ]
  end

  def fetch_chat_state(ctx) do
    state = CuteFemBot.Persistence.get_moderation_chat_state(ctx.deps.persistence)
    {:cont, Map.put(ctx, :moderation_chat_state, state)}
  end

  def handle_message(%{moderation_chat_state: state, update: %{"message" => msg}} = ctx) do
    msg_parsed = parse_msg(msg)

    send_msg! = fn body ->
      {:ok, _} =
        CuteFemBot.Telegram.Api.send_message(
          ctx.deps.api,
          body
          |> Map.merge(%{
            "reply_to_message_id" => msg["message_id"],
            "chat_id" => msg["chat"]["id"],
            "parse_mode" => "html"
          })
        )
    end

    set_chat_state = fn state ->
      CuteFemBot.Persistence.set_moderation_chat_state(ctx.deps.persistence, state)
    end

    case msg_parsed do
      :cmd_cancel ->
        case state do
          nil ->
            send_msg!.(%{"text" => "Нечего отменять"})
            :halt

          _ ->
            set_chat_state.(nil)
            send_msg!.(%{"text" => "Окей, отмена операции"})
            :halt
        end

      :cmd_schedule ->
        set_chat_state.({:schedule, :start})

        send_msg!.(%{
          "text" => """
          Давайте разбираться с расписанием

          set - установить расписание
          show - показать текущее расписание

          /cancel для отмены операции
          /schedule чтобы начать заново
          """
        })

        :halt

      {:regular_msg, msg} ->
        case state do
          nil ->
            send_msg!.(%{
              "text" => """
              Я не знаю, что ты хочешь v_v

              Используй /schedule для установки или просмотра расписания.
              Управлять списком бана пока нельзя.
              Получать доступ к очереди постинга тоже (смотреть её, возможно отменять).
              """
            })

            :halt

          {:schedule, :start} ->
            case msg["text"] do
              "set" ->
                set_chat_state.({:schedule, :set, :cron, Posting.new()})

                send_msg!.(%{
                  "text" => "Окей, пришли мне крон расписания"
                })

                :halt

              "show" ->
                current_posting = CuteFemBot.Persistence.get_posting(ctx.deps.persistence)

                formatted =
                  case current_posting do
                    nil ->
                      "Не установлено"

                    posting ->
                      if Posting.is_complete?(posting) do
                        {:ok, cron} = Posting.format_cron(posting)

                        next_fire =
                          with {:ok, x} <-
                                 Posting.compute_next_posting_time(
                                   posting,
                                   DateTime.to_naive(DateTime.utc_now())
                                 ),
                               do: CuteFemBot.Util.format_datetime(x)

                        {:ok, flush} = Posting.format_flush(posting)

                        """
                        Расписание: <code>#{cron}</code>
                        Flush: #{flush}
                        Следующий пост: #{next_fire} (UTC)
                        """
                        |> String.trim()
                      else
                        "Ошибка: нужно установить заново"
                      end
                  end

                send_msg!.(%{
                  "text" => """
                  <b>Текущее расписание</b>

                  #{formatted}

                  tip: операция не остановлена, можно опять ввести set или show
                  ...или /cancel для отмены
                  """,
                  "parse_mode" => "markdown"
                })

                :halt

              _ ->
                send_msg!.(%{"text" => "Не понимаю, что вы хотите"})
                :halt
            end

          {:schedule, :set, :cron, %Posting{} = state} ->
            raw_cron = msg["text"]

            case Posting.put_raw_cron(state, raw_cron) do
              {:ok, updated} ->
                set_chat_state.({:schedule, :set, :flush, updated})

                send_msg!.(%{
                  "text" => """
                  Расписание понял. Теперь пришли, <i>как</i> постить - фиксированное число [картинок] или диапазон.

                  Пример:

                  6
                  9000
                  4-9
                  """
                })

                :halt

              {:error, msg} ->
                send_msg!.(%{
                  "text" => """
                  Не понял. Ты, наверное, сделал очепятку?

                  <i>tip: #{msg}</i>
                  """
                })

                :halt
            end

          {:schedule, :set, :flush, %Posting{} = state} ->
            raw_flush = msg["text"]

            case Posting.put_raw_flush(state, raw_flush) do
              {:ok, updated} ->
                CuteFemBot.Persistence.set_posting(ctx.deps.persistence, updated)
                CuteFemBot.Logic.Posting.reschedule(ctx.deps.posting)
                set_chat_state.(nil)
                send_msg!.(%{"text" => "Ня. Новое расписание принято."})
                :halt

              {:error, err} ->
                send_msg!.(%{
                  "text" => """
                  Не, ну я бы понял, если бы ты ошибся с написанием крона, но тут-то вроде всё просто... попробуй ещё раз, зай

                  <i>tip: #{err}</i>
                  """
                })

                :halt
            end

          unknown_state ->
            send_msg!.(%{
              "text" => """
              Ой, а у меня крыша потекла :|

              Попробуй /cancel что-ли сделать

              А это вот покажи моему создателю: #{inspect(unknown_state)}
              """
            })

            :halt
        end
    end
  end

  defp parse_msg(msg) do
    commands = find_all_commands(msg)

    cond do
      "cancel" in commands -> :cmd_cancel
      "schedule" in commands -> :cmd_schedule
      true -> {:regular_msg, msg}
    end
  end

  defp find_all_commands(%{"entities" => entities, "text" => text}) do
    text_codepoints = String.codepoints(text)

    entities
    |> Stream.map(fn entity ->
      case entity do
        %{"type" => "bot_command", "offset" => offset, "length" => len} ->
          with %{cmd: cmd} <-
                 Enum.slice(text_codepoints, offset..(offset + len))
                 |> Enum.join("")
                 |> CuteFemBot.Util.parse_command(),
               do: cmd

        _ ->
          nil
      end
    end)
    |> Stream.filter(fn x -> not is_nil(x) end)
    |> Enum.to_list()
  end

  defp find_all_commands(_), do: []
end
