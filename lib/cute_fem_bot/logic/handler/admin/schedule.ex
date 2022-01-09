defmodule CuteFemBot.Logic.Handler.Admin.Schedule do
  alias CuteFemBot.Core.Posting
  alias CuteFemBot.Telegram.Types.Message
  alias CuteFemBot.Telegram.Api
  alias CuteFemBot.Persistence
  alias CuteFemBot.Logic.Handler.Ctx

  import CuteFemBot.Logic.Handler.Admin.Shared

  def command_schedule(ctx) do
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

  def handle(ctx) do
    case chat_state(ctx) do
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
                command_schedule(ctx)
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
            raise_invalid_chat_state!(ctx, unknown_state)
            :halt
        end

      _ ->
        # skip, out of "schedule" scope
        :cont
    end
  end

  defp schedule_show(ctx) do
    current_posting = CuteFemBot.Persistence.get_posting(Ctx.deps_persistence(ctx))

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
                   do: CuteFemBot.Util.format_datetime_msk(x)

            {:ok, flush} = Posting.format_flush(posting)

            """
            Крон: <code>#{cron}</code>
            Flush: #{flush}
            Следующий пост: #{next_fire}

            <i>tip: расшифровать и составить крон можешь на https://crontab.guru/</i>
            """
            |> String.trim()
          else
            "Ошибка: нужно установить заново"
          end
      end

    {:schedule, {:start, msg_id}} = chat_state(ctx)

    Api.request(Ctx.deps_api(ctx),
      method_name: "editMessageText",
      body: %{
        "chat_id" => get_admin_id(ctx),
        "message_id" => msg_id,
        "text" => """
        <b>Текущее расписание</b>

        #{formatted}

        <i>tip: команда /schedule завершена. Чтобы настроить расписание, её нужно вызвать заново.</i>
        """,
        "parse_mode" => "html",
        "disable_web_page_preview" => true
      }
    )

    set_chat_state!(ctx, nil)
  end
end
