defmodule CuteFemBot.Logic.Handler.Middleware.Moderator do
  @moduledoc """
  Implying that if context enters this module it means that message from moderation for sure
  """

  alias CuteFemBot.Core.Posting
  alias CuteFemBot.Telegram.Types.Message
  alias CuteFemBot.Telegram.Api
  alias CuteFemBot.Persistence
  alias CuteFemBot.Logic.Handler.Ctx
  alias CuteFemBot.Core.Suggestion

  require Logger

  def main() do
    [
      :fetch_chat_state,
      :find_commands_in_message,
      :handle_commands,
      :handle_suggestions_callbacks,
      :handle_queue,
      :handle_schedule,
      :skip
    ]
  end

  @spec fetch_chat_state(%{
          :deps =>
            atom
            | %{
                :persistence => atom | pid | {atom, any} | {:via, atom, any},
                optional(any) => any
              },
          optional(any) => any
        }) ::
          {:cont,
           %{
             :deps =>
               atom
               | %{
                   :persistence => atom | pid | {any, any} | {any, any, any},
                   optional(any) => any
                 },
             :moderation_chat_state => any,
             optional(any) => any
           }}
  def fetch_chat_state(ctx) do
    state = CuteFemBot.Persistence.get_moderation_chat_state(ctx.deps.persistence)
    {:cont, Map.put(ctx, :moderation_chat_state, state)}
  end

  @spec find_commands_in_message(%{:update => any, optional(any) => any}) ::
          {:cont, %{:commands => any, :update => any, optional(any) => any}}
  def find_commands_in_message(ctx) do
    cmds =
      case ctx.update do
        {:message, msg} -> CuteFemBot.Util.find_all_commands(msg)
        _ -> []
      end

    {:cont, Map.put(ctx, :commands, cmds)}
  end

  def handle_commands(ctx) do
    case ctx.commands do
      %{"queue" => _} ->
        command_queue(ctx)
        :halt

      %{"schedule" => _} ->
        command_schedule(ctx)
        :halt

      %{"cancel" => _} ->
        command_cancel(ctx)
        :halt

      _ ->
        :cont
    end
  end

  def command_queue(ctx) do
    queue = CuteFemBot.Persistence.get_approved_queue(ctx.deps.persistence)
    queue_len = length(queue)

    if queue_len > 0 do
      msg =
        send_msg!(
          ctx,
          Message.with_text("""
          <b>Очередь</b>

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
    else
      send_msg!(ctx, Message.with_text("Очередь пуста :<"))
      set_chat_state!(ctx, nil)
    end
  end

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

  def handle_suggestions_callbacks(ctx) do
    with {:callback_query,
          %{
            "id" => query_id,
            "message" => %{"message_id" => query_msg_id},
            "data" => query_data
          }} <- ctx.update,
         {:ok, %{file_id: file_id, user_id: user_id}} <-
           find_suggestion_msg(ctx, query_msg_id) do
      Api.answer_callback_query(Ctx.deps_api(ctx), query_id)

      query_parsed =
        case query_data do
          "approve" -> {:ok, :approve}
          "reject" -> {:ok, :reject}
          "ban" -> {:ok, :ban}
          _ -> :error
        end

      suggestion_callback_answer = fn action ->
        # reply to message
        # edit message reply markup

        text =
          case action do
            :approve -> "ОК, добавил в очередь"
            :reject -> "ОК, мимо"
            :ban -> "ОК, забанен"
          end

        send_msg!(ctx, Message.with_text(text) |> Message.set_reply_to(query_msg_id))

        Api.request!(Ctx.deps_api(ctx),
          method_name: "editMessageReplyMarkup",
          body: %{
            "chat_id" => ctx.config.moderation_chat_id,
            "message_id" => query_msg_id
          }
        )
      end

      case query_parsed do
        :error ->
          nil

        {:ok, action} ->
          case action do
            :approve ->
              Persistence.approve_media(Ctx.deps_persistence(ctx), file_id)

            :reject ->
              Persistence.reject_media(Ctx.deps_persistence(ctx), file_id)

            :ban ->
              Persistence.ban_user(Ctx.deps_persistence(ctx), user_id)
          end

          suggestion_callback_answer.(action)
      end

      :halt
    else
      _ -> :cont
    end
  end

  defp find_suggestion_msg(ctx, msg_id) do
    Persistence.find_suggestion_by_moderation_msg(Ctx.deps_persistence(ctx), msg_id)
  end

  def handle_queue(ctx) do
    with {:queue, state} <- ctx.moderation_chat_state do
      case state do
        {:start, message_id} ->
          # we are waiting for the "observe" callback query, and only for it

          with {:callback_query, %{"id" => query_id} = query} <- ctx.update do
            case query do
              %{"message" => %{"message_id" => ^message_id}, "data" => "observe"} ->
                # updates chat state automatically
                queue_observing_update(ctx, nil, 0)

              _ ->
                Api.answer_callback_query(Ctx.deps_api(ctx), query_id)
            end
          else
            _ ->
              send_msg!(ctx, Message.with_text("Не понял"))
              command_queue(ctx)
          end

        {:observing, message_id, index} ->
          # we are looking for callback cmds: "inc", "dec", "cancel"
          # if message received, re-send queue observing message
          case ctx.update do
            {:callback_query, %{"id" => query_id} = query} ->
              case query do
                %{"message" => %{"message_id" => ^message_id}, "data" => query_data} ->
                  case query_data do
                    "inc" ->
                      queue_observing_update(ctx, message_id, index + 1)
                      :ok

                    "dec" ->
                      queue_observing_update(ctx, message_id, index - 1)
                      :ok

                    "cancel" ->
                      command_cancel(ctx)
                      :ok

                    _ ->
                      :fail
                  end

                _ ->
                  :fail
              end

              Api.answer_callback_query(Ctx.deps_api(ctx), query_id)

            _ ->
              # it should update message id automatically
              queue_observing_update(ctx, nil, index)
          end

        unknown_state ->
          report_some_invalid_state(ctx, unknown_state)
      end

      :halt
    else
      _ -> :cont
    end
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
            report_some_invalid_state(ctx, unknown_state)
            :halt
        end

      _ ->
        # skip, out of "schedule" scope
        :cont
    end
  end

  defp report_some_invalid_state(ctx, state) do
    send_msg!(ctx, %{
      "text" => """
      Ой, а у меня крыша потекла :|

      Попробуй /cancel

      А это вот покажи моему создателю: <code>#{inspect(state)}</code>
      """,
      parse_mode: "html"
    })
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
      "parse_mode" => "html"
    })
  end

  defp queue_observing_update(ctx, message_id, index) do
    # edit or send new message with info and callback buttons
    # update chat state with appropriate state

    # visual state depends on queue and index
    # if index out of scope, it should be normalized
    # if queue is empty, send appropriate message and set clear chat state (nil)

    queue = Persistence.get_approved_queue(Ctx.deps_persistence(ctx))
    queue_len = length(queue)

    if queue_len == 0 do
      # informing about empty queue, setting state to nil

      queue_observe_inform_empty(ctx, message_id)

      set_chat_state!(ctx, nil)
    else
      # normalizing index
      idx = norm_queue_index(queue_len, index)

      # getting actual representation media
      media =
        case Enum.at(queue, idx) do
          %Suggestion{} = x -> x
        end

      # constructing generic message data
      caption = queue_observe_msg_caption(ctx, media, idx, queue_len)
      inline_keyboard = queue_observe_msg_inline_keyboard(idx, queue_len)

      # applying changes to telegram
      msg_id = queue_observe_apply_msg(ctx, message_id, media, caption, inline_keyboard)

      # saving chat state
      set_chat_state!(ctx, {:queue, {:observing, msg_id, idx}})
    end
  end

  defp queue_observe_msg_caption(ctx, %Suggestion{user_id: uid}, index, len) do
    user_formatted =
      with user_data <- Persistence.get_user_meta(Ctx.deps_persistence(ctx), uid) do
        case user_data do
          :not_found ->
            link = CuteFemBot.Util.user_link(uid)
            "<i>Нет данных (<a href=\"#{link}\">пермалинк</a>)</i>"

          {:ok, data} ->
            CuteFemBot.Util.format_user_name(data, :html)
        end
      end

    """
    <b>Предложка</b>: #{index + 1} из #{len}

    Отправил: #{user_formatted}
    """
    |> String.trim()
  end

  defp queue_observe_msg_inline_keyboard(idx, queue_len)
       when idx >= 0 and idx < queue_len do
    buttons =
      with inc_dec <-
             (cond do
                queue_len == 1 -> []
                idx == 0 -> [:inc]
                idx == queue_len - 1 -> [:dec]
                true -> [:dec, :inc]
              end) do
        [:cancel | inc_dec]
      end
      |> Enum.map(fn btn ->
        {text, data} =
          case btn do
            :cancel -> {"Отмена", "cancel"}
            :inc -> {"»", "inc"}
            :dec -> {"«", "dec"}
          end

        %{"text" => text, "callback_data" => data}
      end)

    %{
      "inline_keyboard" => [buttons]
    }
  end

  defp queue_observe_apply_msg(
         ctx,
         maybe_current_message_id,
         %Suggestion{} = media,
         caption,
         inline_keyboard
       ) do
    api = ctx |> Ctx.deps_api()
    chat_id = ctx.config.moderation_chat_id

    case maybe_current_message_id do
      nil ->
        # new message
        %{method_name: method, body_part: media_body} = Suggestion.to_send(media)

        %{"message_id" => msg_id} =
          Api.request!(api,
            method_name: method,
            body:
              media_body
              |> Map.merge(%{
                "chat_id" => chat_id,
                "caption" => caption,
                "parse_mode" => "html",
                "reply_markup" => inline_keyboard
              })
          )

        msg_id

      msg_id ->
        # editing exiting message
        Api.request!(
          api,
          method_name: "editMessageCaption",
          body: %{
            "chat_id" => chat_id,
            "message_id" => msg_id,
            "caption" => caption,
            "parse_mode" => "html",
            "reply_markup" => inline_keyboard
          }
        )

        Api.request!(
          api,
          method_name: "editMessageMedia",
          body: %{
            "chat_id" => chat_id,
            "message_id" => msg_id,
            "media" => %{
              "type" => media.type,
              "media" => media.file_id
            }
          }
        )

        msg_id
    end
  end

  defp queue_observe_inform_empty(ctx, maybe_current_message_id) do
    info_text = "В очереди ничего больше нет :<"
    chat_id = ctx.config.moderation_chat_id
    api = ctx |> Ctx.deps_api()

    case maybe_current_message_id do
      nil ->
        # just send new text message
        {:ok, _} =
          Api.send_message(api, Message.with_text(info_text) |> Message.set_chat_id(chat_id))

      msg_id ->
        Api.request!(api,
          method_name: "editMessageCaption",
          body: %{
            "chat_id" => chat_id,
            "message_id" => msg_id,
            "caption" => info_text,
            "reply_markup" => nil
          }
        )
    end
  end

  def skip(_) do
    :halt
  end

  defp send_msg!(ctx, msg) do
    Ctx.send_message_to_moderation!(ctx, msg)
  end

  defp set_chat_state!(ctx, state) do
    :ok = CuteFemBot.Persistence.set_moderation_chat_state(ctx.deps.persistence, state)
  end

  defp norm_queue_index(len, _) when len <= 0, do: raise("Invalid len: #{len}")
  defp norm_queue_index(_, index) when index < 0, do: 0
  defp norm_queue_index(len, index) when index >= len, do: len - 1
  defp norm_queue_index(_, idx), do: idx
end
