defmodule CuteFemBot.Core.Schedule.Entry do
  use TypedStruct

  alias __MODULE__, as: Self

  typedstruct do
    field(:cron, any(), default: nil)
    field(:flush, any(), default: nil)
  end

  @spec new :: Self.t()
  def new() do
    %Self{}
  end

  @spec put_raw_cron(Self.t(), binary) :: {:error, binary} | {:ok, Self.t()}
  def put_raw_cron(%Self{} = self, raw) when is_binary(raw) do
    case Crontab.CronExpression.Parser.parse(raw) do
      {:ok, parsed} -> {:ok, %Self{self | cron: parsed}}
      {:error, err} -> {:error, err}
    end
  end

  @spec put_raw_flush(Self.t(), binary) :: {:ok, Self.t()} | {:error, :invalid_flushing}
  def put_raw_flush(%Self{} = self, raw) when is_binary(raw) do
    case parse_flush(raw) do
      {:ok, x} -> {:ok, %Self{self | flush: x}}
      :error -> {:error, :invalid_flushing}
    end
  end

  @spec is_complete?(Self.t()) :: boolean
  def is_complete?(%Self{} = self) when is_nil(self.cron) or is_nil(self.flush), do: false
  def is_complete?(%Self{}), do: true

  @spec compute_next(
          list(Self.t()) | Self.t(),
          DateTime.t() | NaiveDateTime.t(),
          binary()
        ) ::
          {:error, any}
          | {:ok, DateTime.t(), pos_integer()}
  def compute_next(many_items, now, time_zone \\ "Europe/Moscow")

  def compute_next(many_items, now, time_zone)
      when is_list(many_items) and length(many_items) > 0 do
    reduced =
      Enum.reduce_while(many_items, [], fn %Self{} = self, acc ->
        case compute_next(self, now, time_zone) do
          {:error, _} = err -> {:halt, err}
          {:ok, time, flush} -> {:cont, [{time, flush} | acc]}
        end
      end)

    case reduced do
      {:error, _} = err ->
        err

      computed ->
        {time, flush} = Enum.min_by(computed, fn {time, _} -> time end)
        {:ok, time, flush}
    end
  end

  def compute_next(%Self{} = self, now, time_zone) do
    with {:ok, time} <- compute_next_posting_time(self, now, time_zone),
         {:ok, flush} <- compute_flush_count(self) do
      {:ok, time, flush}
    end
  end

  defp compute_next_posting_time(%Self{} = self, now, tz) do
    now =
      case now do
        %NaiveDateTime{} -> now
        %DateTime{} = dt -> dt |> DateTime.shift_zone!(tz) |> DateTime.to_naive()
      end

    if not is_complete?(self) do
      {:error, :state_incomplete}
    else
      with {:ok, %NaiveDateTime{} = naive} <-
             Crontab.Scheduler.get_next_run_date(self.cron, now),
           {:ok, msk} <- DateTime.from_naive(naive, tz) do
        {:ok, msk}
      end
    end
  end

  defp compute_flush_count(%Self{} = self) do
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

  @spec format_cron(Self.t()) :: {:error, :no_cron} | {:ok, binary}
  def format_cron(%Self{cron: nil}), do: {:error, :no_cron}

  def format_cron(%Self{cron: cron}) do
    {:ok, Crontab.CronExpression.Composer.compose(cron)}
  end

  @spec format_flush(Self.t()) :: {:error, :no_flush} | {:ok, binary}
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
              int = String.to_integer(fixed)

              if int > 0 do
                {:fixed, int}
              else
                :error
              end

            [_, _] = range ->
              [from, to] = range |> Enum.map(&String.to_integer/1)

              if to >= from and from > 0 do
                if to == from do
                  {:fixed, to}
                else
                  {:range, from, to}
                end
              else
                :error
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
