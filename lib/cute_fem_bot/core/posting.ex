defmodule CuteFemBot.Core.Posting do
  use TypedStruct

  alias __MODULE__, as: Self

  typedstruct do
    field(:cron, any(), default: nil)
    field(:flush, any(), default: nil)
  end

  def new() do
    %Self{}
  end

  def put_raw_cron(%Self{} = self, raw) do
    case Crontab.CronExpression.Parser.parse(raw) do
      {:ok, parsed} -> {:ok, %Self{self | cron: parsed}}
      {:error, err} -> {:error, err}
    end
  end

  def put_raw_flush(%Self{} = self, raw) do
    case parse_flush(raw) do
      {:ok, x} -> {:ok, %Self{self | flush: x}}
      :error -> {:error, :invalid_flushing}
    end
  end

  def is_complete?(%Self{} = self) when is_nil(self.cron) or is_nil(self.flush), do: false
  def is_complete?(_), do: true

  def compute_next_posting_time(%Self{} = self, now) do
    if not is_complete?(self) do
      {:error, :state_incomplete}
    else
      Crontab.Scheduler.get_next_run_date(self.cron, now)
    end
  end

  def compute_flush_count(%Self{} = self) do
    if is_complete?(self) do
      count =
        case self.flush do
          {:fixed, count} ->
            count

          {:range, from, to} ->
            (:rand.uniform(to - from) + from) |> :math.floor() |> trunc()
        end

      {:ok, count}
    else
      {:error, :state_incomplete}
    end
  end

  def format_cron(%Self{cron: nil}), do: {:error, :no_cron}

  def format_cron(%Self{cron: cron}) do
    {:ok, Crontab.CronExpression.Composer.compose(cron)}
  end

  def format_flush(%Self{flush: nil}), do: {:error, :no_flush}

  def format_flush(%Self{flush: flush}) do
    formatted =
      case flush do
        {:fixed, count} -> "#{count}"
        {:range, from, to} -> "#{from}-#{to}"
      end

    {:ok, formatted}
  end

  defp parse_flush(raw) do
    case Regex.scan(~r{^\s*(\d+)\s*(?:\-\s*(\d+)\s*)?$}, raw) do
      [[_ | groups]] ->
        parsed =
          case groups do
            [fixed] ->
              {:fixed, String.to_integer(fixed)}

            [_, _] = range ->
              [from, to] = range |> Enum.map(&String.to_integer/1)

              if to < from do
                :error
              else
                {:range, from, to}
              end

            _ ->
              :error
          end

        case parsed do
          :error -> :error
          x -> {:ok, x}
        end

      _ ->
        :error
    end
  end
end
