defmodule CuteFemBot.Logic.Handler.Admin.Queue do
  alias CuteFemBot.Telegram.Types.Message
  alias CuteFemBot.Telegram.Api
  alias CuteFemBot.Persistence
  alias CuteFemBot.Logic.Handler.Ctx
  alias CuteFemBot.Core.Suggestion

  import CuteFemBot.Logic.Handler.Admin.Shared

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

    def btn_key_to_data(key) when key in [:inc, :dec, :cancel_approved],
      do: Atom.to_string(key)

    def btn_data_to_key(data) when data in ["inc", "dec", "cancel_approved"],
      do: {:ok, String.to_existing_atom(data)}

    def btn_data_to_key(_), do: :error
  end

  def command_queue(ctx) do
    stat =
      [:sfw, :nsfw]
      |> Enum.map(fn category ->
        {category,
         length(CuteFemBot.Persistence.get_approved_queue(ctx.deps.persistence, category))}
      end)
      |> Enum.map(fn {cat, len} -> "#{cat}: #{len}" end)
      |> Enum.join("\n")

    send_msg!(
      ctx,
      Message.with_text("""
      <b>Очередь</b>

      #{stat}
      """)
    )

    set_chat_state!(ctx, nil)
  end

  def handle(ctx) do
    with {:queue, state} <- chat_state(ctx) do
      case state do
        {:start, message_id} ->
          # we are waiting for the "observe" callback query, and only for it

          with {:callback_query, %{"id" => query_id} = query} <- ctx.update do
            case query do
              %{"message" => %{"message_id" => ^message_id}, "data" => "observe"} ->
                send_msg!(ctx, Message.with_text("Я пока что разучился показывать очередь :p"))
                set_chat_state!(ctx, nil)

              # # updates chat state automatically
              # apply_observing_update(ctx, %Observing{
              #   current_queue_index: 0,
              #   control_msg_id: message_id
              # })

              _ ->
                Api.answer_callback_query(Ctx.deps_api(ctx), query_id)
            end
          else
            _ ->
              send_msg!(ctx, Message.with_text("Не понял"))
              command_queue(ctx)
          end

        # {:observing, %Observing{} = state} ->
        #   # we are looking for callback cmds: "inc", "dec", "cancel"
        #   # if message received, re-send queue observing message
        #   case ctx.update do
        #     {:callback_query, %{"id" => query_id} = query} ->
        #       msg_id = state.control_msg_id

        #       case query do
        #         %{
        #           "message" => %{
        #             "message_id" => ^msg_id
        #           },
        #           "data" => query_data
        #         } ->
        #           with {:ok, key} <- query_data |> Observing.btn_data_to_key() do
        #             case key do
        #               :inc ->
        #                 apply_observing_update(ctx, state |> Observing.inc())

        #               :dec ->
        #                 apply_observing_update(ctx, state |> Observing.dec())

        #               :cancel_approved ->
        #                 pers = Ctx.deps_persistence(ctx)
        #                 queue = Persistence.get_approved_queue(pers)

        #                 suggestion =
        #                   case Enum.at(queue, state.current_queue_index) do
        #                     %Suggestion{} = x -> x
        #                   end

        #                 Persistence.cancel_approved(pers, suggestion.file_id)

        #                 apply_observing_update(ctx, state)
        #             end

        #             :ok
        #           end

        #         _ ->
        #           :error
        #       end

        #       Api.answer_callback_query(Ctx.deps_api(ctx), query_id)

        #     _ ->
        #       # it should update message id automatically
        #       apply_observing_update(ctx, state |> Observing.reset_messages())
        #   end

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

      observing_update_control(
        ctx,
        state,
        text_queue_is_empty(),
        nil
      )

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
        [:cancel_approved | inc_dec]
      end
      |> Enum.map(fn btn ->
        btn_data = Observing.btn_key_to_data(btn)

        btn_caption =
          case btn do
            :inc -> "»"
            :dec -> "«"
            :cancel_approved -> "Не ня"
          end

        %{"text" => btn_caption, "callback_data" => btn_data}
      end)

    %{
      "inline_keyboard" => [buttons]
    }
  end

  defp observing_delete_preview(_ctx, %Observing{preview_msg_id: msg} = state) when is_nil(msg),
    do: state

  defp observing_delete_preview(ctx, %Observing{preview_msg_id: msg} = state) do
    Api.delete_message!(Ctx.deps_api(ctx), get_admin_id(ctx), msg)
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
        |> Message.set_chat_id(get_admin_id(ctx))
      )

    Observing.update_control_message(state, new_message_id)
  end

  defp observing_update_control(ctx, %Observing{control_msg_id: msg} = state, text, reply_markup) do
    # updating message
    Api.request!(Ctx.deps_api(ctx),
      method_name: "editMessageText",
      body: %{
        "chat_id" => get_admin_id(ctx),
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
            "chat_id" => get_admin_id(ctx)
          })
      )

    msg_id
  end

  defp text_queue_is_empty() do
    "Очередь пуста :<" |> CuteFemBot.Util.escape_html()
  end

  defp norm_queue_index(len, _) when len <= 0, do: raise("Invalid len: #{len}")
  defp norm_queue_index(_, index) when index < 0, do: 0
  defp norm_queue_index(len, index) when index >= len, do: len - 1
  defp norm_queue_index(_, idx), do: idx
end
