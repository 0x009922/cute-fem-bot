defmodule CuteFemBot.Logic.Handler.Middleware.Moderator.Queue do
  alias CuteFemBot.Telegram.Types.Message
  alias CuteFemBot.Telegram.Api
  alias CuteFemBot.Persistence
  alias CuteFemBot.Logic.Handler.Ctx
  alias CuteFemBot.Core.Suggestion

  import CuteFemBot.Logic.Handler.Middleware.Moderator.Shared

  defmodule Observing do
    use TypedStruct

    alias __MODULE__, as: Self

    typedstruct enforce: true do
      field(:control_msg_id, any(), default: nil)
      field(:preview_msg_id, any(), default: nil)
      field(:current_queue_index, pos_integer())
    end

    def inc(%Self{} = self) do
      upd_index(self, fn x -> x + 1 end)
    end

    def dec(%Self{} = self) do
      upd_index(self, fn x -> x - 1 end)
    end

    def reset_messages(%Self{current_queue_index: idx}) do
      %Self{current_queue_index: idx}
    end

    def update_control_message(%Self{} = self, id) do
      %Self{self | control_msg_id: id}
    end

    def update_preview_message(%Self{} = self, id) do
      %Self{self | preview_msg_id: id}
    end

    defp upd_index(%Self{} = self, fun) do
      Map.update!(self, :current_queue_index, fun)
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

  def main() do
    [:handle]
  end

  def handle(ctx) do
    with {:queue, state} <- ctx.moderation_chat_state do
      case state do
        {:start, message_id} ->
          # we are waiting for the "observe" callback query, and only for it

          with {:callback_query, %{"id" => query_id} = query} <- ctx.update do
            case query do
              %{"message" => %{"message_id" => ^message_id}, "data" => "observe"} ->
                # updates chat state automatically
                apply_observing_update(ctx, %Observing{
                  current_queue_index: 0,
                  control_msg_id: message_id
                })

              _ ->
                Api.answer_callback_query(Ctx.deps_api(ctx), query_id)
            end
          else
            _ ->
              send_msg!(ctx, Message.with_text("Не понял"))
              command_queue(ctx)
          end

        {:observing, %Observing{} = state} ->
          # we are looking for callback cmds: "inc", "dec", "cancel"
          # if message received, re-send queue observing message
          case ctx.update do
            {:callback_query, %{"id" => query_id} = query} ->
              msg_id = state.control_msg_id

              case query do
                %{
                  "message" => %{
                    "message_id" => ^msg_id
                  },
                  "data" => query_data
                } ->
                  case query_data do
                    "inc" ->
                      apply_observing_update(ctx, state |> Observing.inc())
                      :ok

                    "dec" ->
                      apply_observing_update(ctx, state |> Observing.dec())
                      :ok

                    "cancel" ->
                      observing_delete_preview(ctx, state)
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
              apply_observing_update(ctx, state |> Observing.reset_messages())
          end

        unknown_state ->
          raise_invalid_chat_state!(ctx, unknown_state)
      end

      :halt
    else
      _ -> :cont
    end
  end

  defp apply_observing_update(ctx, %Observing{} = state) do
    # edit or send new message with info and callback buttons
    # update chat state with appropriate state

    # visual state depends on queue and index
    # if index out of scope, it should be normalized
    # if queue is empty, send appropriate message and set clear chat state (nil)

    queue = Persistence.get_approved_queue(Ctx.deps_persistence(ctx))
    queue_len = length(queue)

    if queue_len == 0 do
      # informing about empty queue, setting state to nil
      observing_delete_preview(ctx, state)
      observing_update_control(ctx, state, "В очереди ничего больше нет :<", nil)
      set_chat_state!(ctx, nil)
    else
      # normalizing index
      idx = norm_queue_index(queue_len, state.current_queue_index)

      # getting actual representation media
      media =
        case Enum.at(queue, idx) do
          %Suggestion{} = x -> x
        end

      # constructing generic message data
      caption = observing_msg_caption(ctx, media, idx, queue_len)
      inline_keyboard = observing_msg_inline_keyboard(idx, queue_len)

      # applying changes to telegram
      state =
        with state <- observing_delete_preview(ctx, state),
             state <- observing_update_control(ctx, state, caption, inline_keyboard),
             preview_msg_id <- observing_send_preview(ctx, media) do
          Observing.update_preview_message(state, preview_msg_id)
        end

      # saving chat state
      set_chat_state!(ctx, {:queue, {:observing, state}})
    end
  end

  defp observing_msg_caption(ctx, %Suggestion{user_id: uid}, index, len) do
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

  defp observing_msg_inline_keyboard(idx, queue_len)
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

  defp observing_delete_preview(_ctx, %Observing{preview_msg_id: msg} = state) when is_nil(msg),
    do: state

  defp observing_delete_preview(ctx, %Observing{preview_msg_id: msg} = state) do
    Api.delete_message!(Ctx.deps_api(ctx), Ctx.conf_moderation_chat_id(ctx), msg)
    Observing.update_preview_message(state, nil)
  end

  defp observing_update_control(ctx, %Observing{control_msg_id: msg} = state, text, reply_markup)
       when is_nil(msg) do
    # sending new message
    {:ok, %{"message_id" => new_message_id}} =
      Api.send_message(
        Ctx.deps_api(ctx),
        Message.with_text(text)
        |> Message.set_parse_mode("html")
        |> Message.set_reply_markup(:inline_keyboard_markup, reply_markup)
        |> Message.set_chat_id(Ctx.conf_moderation_chat_id(ctx))
      )

    Observing.update_control_message(state, new_message_id)
  end

  defp observing_update_control(ctx, %Observing{control_msg_id: msg} = state, text, reply_markup) do
    # updating message
    Api.request!(Ctx.deps_api(ctx),
      method_name: "editMessageText",
      body: %{
        "chat_id" => Ctx.conf_moderation_chat_id(ctx),
        "message_id" => msg,
        "text" => text,
        "parse_mode" => "html",
        "reply_markup" => reply_markup
      }
    )

    state
  end

  defp observing_send_preview(ctx, %Suggestion{} = data) do
    %{method_name: method, body_part: media_body} = Suggestion.to_send(data)

    %{"message_id" => msg_id} =
      Api.request!(Ctx.deps_api(ctx),
        method_name: method,
        body:
          media_body
          |> Map.merge(%{
            "chat_id" => Ctx.conf_moderation_chat_id(ctx)
          })
      )

    msg_id
  end

  defp norm_queue_index(len, _) when len <= 0, do: raise("Invalid len: #{len}")
  defp norm_queue_index(_, index) when index < 0, do: 0
  defp norm_queue_index(len, index) when index >= len, do: len - 1
  defp norm_queue_index(_, idx), do: idx
end
