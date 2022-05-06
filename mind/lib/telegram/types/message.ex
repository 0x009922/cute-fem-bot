defmodule Telegram.Types.Message do
  def new() do
    %{
      "parse_mode" => "html"
    }
  end

  def with_text(text) when is_binary(text) do
    new()
    |> set_text(text)
  end

  def with_sticker(sticker) do
    new() |> set_sticker(sticker)
  end

  def set_text(msg, text) do
    Map.put(msg, "text", text)
  end

  def set_chat_id(msg, chat_id) do
    Map.put(msg, "chat_id", chat_id)
  end

  def set_parse_mode(msg, mode) when mode in ["markdown", "html"] do
    Map.put(msg, "parse_mode", mode)
  end

  def set_reply_markup(msg, type, markup, opts \\ [])

  def set_reply_markup(msg, :inline_keyboard_markup, markup, _opts) do
    Map.put(msg, "reply_markup", %{
      "inline_keyboard" => markup
    })
  end

  def set_reply_markup(msg, :reply_keyboard_markup, markup, opts) do
    Map.put(msg, "reply_markup", %{
      "keyboard" => markup,
      "one_time_keyboard" => Keyword.get(opts, :one_time, false),
      "resize_keyboard" => Keyword.get(opts, :resize, false)
    })
  end

  def remove_reply_keyboard(msg) do
    Map.put(msg, "reply_markup", %{
      "remove_keyboard" => true
    })
  end

  def set_reply_to(msg, message_id, allow_sending_without_reply \\ false) do
    Map.put(msg, "reply_to_message_id", message_id)
    |> Map.put("allow_sending_without_reply", allow_sending_without_reply)
  end

  def set_sticker(msg, file_id) do
    Map.put(msg, "sticker", file_id)
  end
end
