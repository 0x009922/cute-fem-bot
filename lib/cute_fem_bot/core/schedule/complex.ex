defmodule CuteFemBot.Core.Schedule.Complex do
  alias CuteFemBot.Core.Schedule.Entry
  alias __MODULE__, as: Self
  use TypedStruct

  @allowed_categories [:sfw, :nsfw]

  typedstruct do
    field(:categories, map(),
      default: @allowed_categories |> Enum.map(fn x -> {x, MapSet.new()} end) |> Enum.into(%{})
    )
  end

  def new() do
    %Self{}
  end

  def from_raw(raw) when is_binary(raw) do
    try do
      complex =
        String.split(raw, "\n")
        |> Stream.with_index()
        |> Stream.map(fn {row, idx} -> {String.trim(row), idx} end)
        |> Stream.filter(fn {row, _} -> row != "" end)
        |> Stream.map(fn {row, idx} ->
          case parse_raw_row(row) do
            {:error, msg} ->
              throw({:row_parse_error, "row #{idx} \"#{row}\" parse error: #{inspect(msg)}"})

            {:ok, entry, category} ->
              {entry, category}
          end
        end)
        |> Enum.reduce(new(), fn {entry, category}, complex ->
          %Self{
            complex
            | categories:
                Map.update!(complex.categories, category, fn set -> MapSet.put(set, entry) end)
          }
        end)

      {:ok, complex}
    catch
      {:row_parse_error, msg} -> {:error, msg}
    end
  end

  def format(%Self{} = self) do
    try do
      formatted =
        Stream.map(@allowed_categories, fn category ->
          cat_capitalized = category |> Atom.to_string() |> String.upcase()

          items =
            Map.fetch!(self.categories, category)
            |> Enum.to_list()
            |> Stream.map(fn %Entry{} = entry ->
              with {:ok, cron} <- Entry.format_cron(entry),
                   {:ok, flush} <- Entry.format_flush(entry) do
                cron <> " \\ " <> flush
              else
                {:error, msg} ->
                  throw({:entry_fmt_error, "unable to format #{inspect(entry)}: #{inspect(msg)}"})
              end
            end)
            |> Enum.sort()

          data =
            cond do
              length(items) == 0 -> "no data"
              true -> Enum.join(items, "\n")
            end

          "#{cat_capitalized}\n#{data}"
        end)
        |> Enum.join("\n\n")

      {:ok, formatted}
    catch
      {:entry_fmt_error, msg} -> {:error, msg}
    end
  end

  def compute_next(%Self{} = self, now, time_zone \\ "Europe/Moscow") do
    try do
      {time, flush, category} =
        self.categories
        |> Stream.flat_map(fn {category, entries} ->
          Stream.map(entries, fn x ->
            case Entry.compute_next(x, now, time_zone) do
              {:ok, next, flush} ->
                {next, flush, category}

              {:error, msg} ->
                throw({:entry_compute_error, "unable to compute #{inspect(x)}: #{inspect(msg)}"})
            end
          end)
        end)
        |> Enum.min_by(fn {time, _, _} -> time end)

      {:ok, time, flush, category}
    catch
      {:entry_compute_error, msg} -> {:error, msg}
    end
  end

  defp parse_raw_row(row) when is_binary(row) do
    case Regex.scan(~r{^(.+?);(.+?);([^;]+)$}, row) do
      [] ->
        {:error, "bad format: it should be \"<category>;<flush>;<cron>\""}

      [[_, category, flush, cron]] ->
        with {:ok, category} <- parse_category(category),
             entry = Entry.new(),
             {:ok, entry} <- Entry.put_raw_flush(entry, flush),
             {:ok, entry} <- Entry.put_raw_cron(entry, cron) do
          {:ok, entry, category}
        end
    end
  end

  defp parse_category(category) when is_binary(category) do
    category = String.downcase(category)

    if category in ["sfw", "nsfw"] do
      {:ok, String.to_existing_atom(category)}
    else
      {:error, "bad category: #{inspect(category)}; sfw or nsfw expected"}
    end
  end
end
