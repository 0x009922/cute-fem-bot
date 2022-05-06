defmodule CuteFemBot.Logic.Speaking do
  def sticker_ignore() do
    [
      "CAACAgIAAxkBAAIEf2HahzwrLKXmtolHntgHJ1ZdMWGYAAKCHAAC4KOCB_nVJkUHUFHyIwQ",
      "CAACAgIAAxkBAAIEh2HaiXVOB4kz14iq3qGNH49DpvC7AAJ0HAAC4KOCBwXaQbYMvaDdIwQ",
      "CAACAgIAAxkBAAIEiWHaic9HnBcpYKThovh_DZKkcq1yAAKpHAAC4KOCB12RbqUyrEkbIwQ"
    ]
    |> Enum.random()
  end

  def sticker_suggestion_accepted() do
    sticker_ok()
  end

  def sticker_welcome() do
    "CAACAgIAAxkBAAIEjWHaikbCbPLXlMZVAuEsB0ldY6RcAAK4HAAC4KOCB3GgINgFRF3fIwQ"
  end

  def sticker_ok() do
    "CAACAgIAAxkBAAIEhWHaiLHl_MQOmcwljqNoHvxfMvJ0AAJaHAAC4KOCB1AVJoJXW7dSIwQ"
  end

  def msg_suggestions_welcome("ru") do
    """
    Привет! :з

    Я люблю контент с милыми парнями. Пришли мне.
    Понимаю <b>фотографии</b>, <b>видео</b> и <b>гифки</b>.
    Как в сжиженном виде, так и нет. Остальное не понимаю.
    """
  end

  def msg_suggestions_welcome(_) do
    """
    Hewwo! :з

    I do like media content with cute boys. Send me some.
    I understand <b>photos</b>, <b>videos</b> and <b>gifs</b>.
    Compressed or not. Anything else I do not understand.
    """
  end

  def msg_suggestions_no_media("ru") do
    "Туть ничего неть"
  end

  def msg_suggestions_no_media(_) do
    "Nothing here"
  end

  def cmd_description_start("ru") do
    "Начать кидать посты в предложку!"
  end

  def cmd_description_start(_) do
    "Start making suggestions!"
  end

  def cmd_description_help("ru") do
    "Получить памятку по использованию"
  end

  def cmd_description_help(_) do
    "Get help about how to use me"
  end
end
