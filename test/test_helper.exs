alias CuteFemBot.Repo

{:ok, _} = Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)

Logger.configure(level: :info)
ExUnit.start()
