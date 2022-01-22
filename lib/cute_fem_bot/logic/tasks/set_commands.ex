defmodule CuteFemBot.Logic.Tasks.SetCommands do
  use Task
  require Logger

  alias CuteFemBot.Logic.Speaking

  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [Keyword.fetch!(arg, :deps)])
  end

  def run(%{api: api, config: config}) do
    Logger.info("Deletting and setting new commands")

    %CuteFemBot.Config{admins: admins} = CuteFemBot.Config.State.lookup!(config)

    # deleting old commands
    Stream.map(admins, fn id -> {scope_chat(id), nil} end)
    |> Stream.concat(["ru", nil] |> Stream.map(fn lang -> {scope_default(), lang} end))
    |> Enum.each(fn {scope, lang} -> delete_commands(api, scope, lang) end)

    # setting new commands
    # for admins
    Stream.map(admins, fn id ->
      {
        scope_chat(id),
        [
          cmd("schedule", "Расписание - просмотр, установка"),
          cmd("posting_mode", "Режим постинга"),
          cmd("queue", "[ИНФОРМАЦИЯ УДАЛЕНА]"),
          cmd("unban", "Разбанить пользователей"),
          cmd("cancel", "Отмена текущей операции"),
          cmd("help", "Памятка по использованию")
        ],
        nil
      }
    end)
    # for regular users
    |> Stream.concat(
      ["ru", nil]
      |> Stream.map(fn lang ->
        {
          scope_default(),
          [
            cmd("start", Speaking.cmd_description_start(lang)),
            cmd("help", Speaking.cmd_description_help(lang))
          ],
          lang
        }
      end)
    )
    # apply
    |> Enum.each(fn {scope, cmds, lang} -> set_commands(api, scope, cmds, lang) end)
  end

  defp delete_commands(api, scope, lang) do
    CuteFemBot.Telegram.Api.request_cast(api,
      method_name: "deleteMyCommands",
      body:
        %{
          "scope" => scope
        }
        |> put_lang(lang)
    )
  end

  defp set_commands(api, scope, commands, lang) do
    CuteFemBot.Telegram.Api.request_cast(api,
      method_name: "setMyCommands",
      body:
        %{
          "scope" => scope,
          "commands" => commands
        }
        |> put_lang(lang)
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

  defp put_lang(map, lang), do: put_if_str(map, "language_code", lang)
  defp put_if_str(map, key, value) when is_binary(value), do: Map.put(map, key, value)
  defp put_if_str(map, _, _), do: map
end
