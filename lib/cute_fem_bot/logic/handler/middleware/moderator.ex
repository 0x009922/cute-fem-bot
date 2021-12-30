defmodule CuteFemBot.Logic.Handler.Middleware.Moderator do
  @moduledoc """
  Implying that if context enters this module it means that message from moderation for sure
  """

  alias CuteFemBot.Core.Posting
  alias CuteFemBot.Telegram.Types.Message
  alias CuteFemBot.Telegram.Api
  alias CuteFemBot.Persistence
  alias CuteFemBot.Logic.Handler.Ctx

  require Logger

  def main() do
    [
      :fetch_chat_state,
      :find_commands_in_message,
      :handle_commands,
      :handle_queue,
      :handle_schedule,
      :skip
    ]
  end

  def fetch_chat_state(ctx) do
    state = CuteFemBot.Persistence.get_moderation_chat_state(ctx.deps.persistence)
    {:cont, Map.put(ctx, :moderation_chat_state, state)}
  end

  def find_commands_in_message(ctx) do
    cmds =
      case ctx.update do
        {:message, msg} -> find_all_commands(msg)
        _ -> []
      end

    {:cont, Map.put(ctx, :commands, cmds)}
  end

  def handle_commands(ctx) do
    Logger.debug(inspect(ctx))

    cond do
      "queue" in ctx.commands ->
        command_queue(ctx)
        :halt

      "schedule" in ctx.commands ->
        command_schedule(ctx)
        :halt

      "cancel" in ctx.commands ->
        Logger.debug("canceling")
        command_cancel(ctx)
        :halt

      true ->
        Logger.debug("no command")
        :cont
    end
  end

  def command_queue(ctx) do
    queue = CuteFemBot.Persistence.get_approved_queue(ctx.deps.persistence)
    queue_len = length(queue)

    msg =
      send_msg!(
        ctx,
        Message.with_text("""
        <b>Очередь<b>

        Сейчас контента в очереди: #{queue_len}
        """)
        |> Message.set_reply_markup(:inline_keyboard_markup, [
          [
            %{
              "text" => "Глянуть, чё там",
              "callback_data" => "observe"
            }
          ]
        ])
      )

    set_chat_state!(ctx, {:queue, {:start, msg["message_id"]}})
  end

  def command_schedule(ctx) do
    schedule_start_action(ctx)
  end

  def command_cancel(ctx) do
    is_there_any? =
      case ctx.moderation_chat_state do
        nil -> false
        _ -> true
      end

    set_chat_state!(ctx, nil)

    send_msg!(
      ctx,
      Message.with_text(
        if is_there_any?, do: "ОК, отменил", else: "ОК, отменил (а было ли что?..)"
      )
    )
  end

  def handle_queue(_ctx) do
    :cont
  end

  def handle_schedule(ctx) do
    case ctx.moderation_chat_state do
      {:schedule, state} ->
        case state do
          {:start, msg_id} ->
            result =
              case ctx.update do
                {
                  :callback_query,
                  %{
                    "id" => query_id,
                    "message" => %{"message_id" => ^msg_id},
                    "data" => callback_data
                  }
                } ->
                  action =
                    case callback_data do
                      "setup" -> :setup
                      "show" -> :show
                      _ -> :error
                    end

                  action_result =
                    case action do
                      :error ->
                        :error

                      :setup ->
                        set_chat_state!(ctx, {:schedule, {:set, :cron, Posting.new()}})

                        send_msg!(
                          ctx,
                          Message.with_text("""
                          Окей, пришли мне крон расписания

                          <i>tip: составить крон можешь на https://crontab.guru/</i>
                          """)
                        )

                        :ok

                      :show ->
                        schedule_show(ctx)
                        :ok
                    end

                  case action_result do
                    :ok ->
                      CuteFemBot.Telegram.Api.answer_callback_query(Ctx.deps_api(ctx), query_id)
                      :ok

                    :error ->
                      :error
                  end
              end

            case result do
              :ok ->
                :halt

              :error ->
                send_msg!(ctx, Message.with_text("Не понял"))
                schedule_start_action(ctx)
                :halt
            end

          {:set, :cron, state} ->
            case ctx.update do
              {:message, msg} ->
                raw_cron = msg["text"]

                case Posting.put_raw_cron(state, raw_cron) do
                  {:ok, updated} ->
                    set_chat_state!(ctx, {:schedule, {:set, :flush, updated}})

                    send_msg!(
                      ctx,
                      Message.with_text("""
                      Расписание понял. Теперь пришли, <i>как</i> постить -
                      фиксированное число [картинок] или диапазон.

                      Пример:

                      6
                      9000
                      4-9
                      """)
                    )

                    :halt

                  {:error, msg} ->
                    send_msg!(
                      ctx,
                      Message.with_text("""
                      Не понял. Ты, наверное, сделал очепятку?

                      <i>tip: #{msg}</i>
                      """)
                    )

                    :halt
                end

              {:callback_query, %{"query_id" => id}} ->
                Api.answer_callback_query(Ctx.deps_api(ctx), id)
                :halt
            end

          {:set, :flush, %Posting{} = state} ->
            case ctx.update do
              {:message, %{"text" => raw_flush}} ->
                case Posting.put_raw_flush(state, raw_flush) do
                  {:ok, updated} ->
                    Persistence.set_posting(ctx.deps.persistence, updated)
                    CuteFemBot.Logic.Posting.reschedule(ctx.deps.posting)
                    set_chat_state!(ctx, nil)
                    send_msg!(ctx, %{"text" => "Ня. Новое расписание принято."})
                    :halt

                  {:error, err} ->
                    send_msg!(ctx, %{
                      "text" => """
                      Не, ну я бы понял, если бы ты ошибся с написанием крона, но тут-то вроде всё просто... попробуй ещё раз, зай

                      <i>tip: #{err}</i>
                      """
                    })

                    :halt
                end

              {:callback_query, %{"query_id" => id}} ->
                Api.answer_callback_query(Ctx.deps_api(ctx), id)
                :halt
            end

          unknown_state ->
            send_msg!(ctx, %{
              "text" => """
              Ой, а у меня крыша потекла :|

              Попробуй /cancel

              А это вот покажи моему создателю: #{inspect(unknown_state)}
              """
            })

            :halt
        end

      _ ->
        # skip, out of "schedule" scope
        :cont
    end
  end

  defp schedule_start_action(ctx) do
    msg =
      send_msg!(
        ctx,
        Message.with_text("""
        Что делаем с расписанием?
        """)
        |> Message.set_reply_markup(:inline_keyboard_markup, [
          [
            %{"text" => "Настройка", "callback_data" => "setup"},
            %{"text" => "Просмотр", "callback_data" => "show"}
          ]
        ])
      )

    set_chat_state!(ctx, {:schedule, {:start, msg["message_id"]}})
  end

  defp schedule_show(ctx) do
    # TODO edit existing message
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
            Крон: <code>#{cron}</code>
            Flush: #{flush}
            Следующий пост: #{next_fire} (UTC)

            <i>tip: расшифровать и составить крон можешь на https://crontab.guru/</i>
            """
            |> String.trim()
          else
            "Ошибка: нужно установить заново"
          end
      end

    send_msg!(ctx, %{
      "text" => """
      <b>Текущее расписание</b>

      #{formatted}
      """,
      "parse_mode" => "markdown"
    })
  end

  def skip(_) do
    :halt
  end

  defp send_msg!(ctx, msg) do
    {:ok, x} =
      CuteFemBot.Telegram.Api.send_message(
        ctx.deps.api,
        msg
        |> Message.set_chat_id(ctx.config.moderation_chat_id)
        |> Message.set_parse_mode("html")
      )

    x
  end

  defp set_chat_state!(ctx, state) do
    :ok = CuteFemBot.Persistence.set_moderation_chat_state(ctx.deps.persistence, state)
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
