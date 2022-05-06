integration_mode? = fn ->
  include =
    ExUnit.configuration()
    |> Keyword.fetch!(:include)

  :integration in include
end

if integration_mode?.() do
  alias CuteFemBot.Repo

  {:ok, _} = Repo.start_link()
  Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)

  Logger.configure(level: :info)
end

ExUnit.configure(exclude: [:integration])
ExUnit.start()
