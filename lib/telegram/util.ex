defmodule Telegram.Util do
  def href_file(token, file_path) do
    "https://api.telegram.org/file/bot#{token}/#{file_path}"
  end

  def href_api(token, method) do
    "https://api.telegram.org/bot#{token}/#{method}"
  end
end
