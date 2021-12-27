defmodule CuteFemBot.Logic.Handler.Middleware do
  def schema() do
    %{
      main: [
        :try_handle_message,
        :try_handle_inline_query_callback,
        :ignore
      ]
    }
  end

  def try_handle_message(update, ctx) do
    case update do
      %{"message" => _} ->
        {:next, :middleware_module, CuteFemBot.Logic.Handler.Middleware.Message}

      _ ->
        :next
    end
  end

  def try_handle_inline_query_callback(_, _) do
    :next
  end

  def ignore(_, _) do
    :halt
  end
end
