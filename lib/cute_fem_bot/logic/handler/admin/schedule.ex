defmodule CuteFemBot.Logic.Handler.Admin.Schedule do
  alias CuteFemBot.Core.Schedule
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
                        set_chat_state!(ctx, {:schedule, :setup})

                        send_msg!(
                          ctx,
                          Message.with_text("""
                          ОК, настраиваем расписание. Оно может быть указано на нескольких строках, \
                          в формате <code>"#{"<category>;<flush>;<cron expression>" |> CuteFemBot.Util.escape_html()}"</code>. <code>category</code> \
                          - это <i>SFW</i> или <i>NSFW</i> (case insensitive).

                          Пример:
                          <pre>
                          sfw;1;0 12-20
                          nsfw;10;*</pre>

                          <i>Tip: составить крон можешь на https://crontab.guru/</i>
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

          :setup ->
            case ctx.update do
              {:message, msg} ->
                user_input = msg["text"]
                parse_result = Schedule.Complex.from_raw(user_input)

                case parse_result do
                  {:ok, schedule} ->
                    Persistence.set_schedule(Ctx.deps_persistence(ctx), schedule)
                    CuteFemBot.Logic.Posting.reschedule(ctx.deps.posting)
                    set_chat_state!(ctx, nil)
                    send_msg!(ctx, %{"text" => "Ня. Новое расписание принято."})
                    :halt

                  {:error, msg} ->
                    send_msg!(
                      ctx,
                      Message.with_text("""
                      Не понял. Ты, наверное, сделал очепятку?
                      <code>Ошибка: #{inspect(msg) |> CuteFemBot.Util.escape_html()}</code>
                      """)
                    )

                    :halt
                end

              {:callback_query, %{"query_id" => id}} ->
                Api.answer_callback_query(Ctx.deps_api(ctx), id)
                :halt
            end

          # {:set, :flush, %Schedule.Entry{} = state} ->
          #   case ctx.update do
          #     {:message, %{"text" => raw_flush}} ->
          #       case Posting.put_raw_flush(state, raw_flush) do
          #         {:ok, updated} ->
          #           Persistence.set_posting(ctx.deps.persistence, updated)
          #           CuteFemBot.Logic.Posting.reschedule(ctx.deps.posting)
          #           set_chat_state!(ctx, nil)
          #           send_msg!(ctx, %{"text" => "Ня. Новое расписание принято."})
          #           :halt

          #         {:error, err} ->
          #           send_msg!(ctx, %{
          #             "text" => """
          #             Не, ну я бы понял, если бы ты ошибся с написанием крона, но тут-то вроде всё просто... попробуй ещё раз, зай

          #             <i>tip: #{err}</i>
          #             """
          #           })

          #           :halt
          #       end

          #     {:callback_query, %{"query_id" => id}} ->
          #       Api.answer_callback_query(Ctx.deps_api(ctx), id)
          #       :halt
          #   end

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
    schedule = CuteFemBot.Persistence.get_schedule(Ctx.deps_persistence(ctx))

    formatted =
      case schedule do
        nil ->
          "Не установлено"

        _ ->
          with {:ok, formatted} <- Schedule.Complex.format(schedule),
               {:ok, formatted_next_fire_timestamps} <- format_next_fire_timestamps(schedule, 10) do
            """
            #{formatted}

            Ближайшие срабатывания:

            <pre>#{formatted_next_fire_timestamps |> CuteFemBot.Util.escape_html()}</pre>
            """
            |> String.trim()
          else
            {:error, err} ->
              "Ой. Что-то не так с расписанием. <code>#{CuteFemBot.Util.inspect_err_html(err)}</code>"
          end
      end

    {:schedule, {:start, msg_id}} = chat_state(ctx)
    set_chat_state!(ctx, nil)

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
  end

  defp format_next_fire_timestamps(%Schedule.Complex{} = schedule, count) do
    try do
      {list, _} =
        Enum.map_reduce(1..count, DateTime.utc_now(), fn _, time ->
          case Schedule.Complex.compute_next(schedule, time) do
            {:ok, time, _flush, category} -> {{time, category}, DateTime.add(time, 30, :second)}
            {:error, msg} -> {:step_error, msg}
          end
        end)

      joined =
        Enum.map(list, fn {time, category} ->
          cat = category |> Atom.to_string() |> String.upcase()
          time = CuteFemBot.Util.format_datetime(time)
          "#{cat}: #{time}"
        end)
        |> Enum.join("\n")

      {:ok, joined}
    catch
      {:step_error, msg} -> {:error, msg}
    end
  end
end
