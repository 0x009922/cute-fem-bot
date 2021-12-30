defmodule CuteFemBot.Logic.Tasks.SetCommands do
  use Task
  require Logger

  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [Keyword.fetch!(arg, :deps)])
  end

  def run(%{api: api, config: config}) do
    Logger.info("Deletting and setting new commands")

    %CuteFemBot.Config{moderation_chat_id: mod_chat} = CuteFemBot.Config.State.get(config)

    delete_commands(api, scope_chat(mod_chat))
    delete_commands(api, scope_default())

    set_commands(api, scope_chat(mod_chat), [
      cmd("schedule", "Расписание - просмотр, установка"),
      cmd("queue", "Очередь - посмотреть [отменить?]"),
      cmd("cancel", "Отмена текущей операции")
    ])

    set_commands(api, scope_default(), [
      cmd("help", "Получить памятку по использованию")
    ])

    Logger.info("Done")
  end

  defp delete_commands(api, scope) do
    CuteFemBot.Telegram.Api.request!(api,
      method_name: "deleteMyCommands",
      body: %{
        "scope" => scope
      }
    )
  end

  defp set_commands(api, scope, commands) do
    CuteFemBot.Telegram.Api.request!(api,
      method_name: "setMyCommands",
      body: %{
        "scope" => scope,
        "commands" => commands
      }
    )
  end

  defp cmd(name, description) do
    %{
      "command" => name,
      "description" => description
    }
  end

  defp scope_chat(chat_id) do
    %{
      "type" => "chat",
      "chat_id" => chat_id
    }
  end

  defp scope_default() do
    %{
      "type" => "default"
    }
  end
end
