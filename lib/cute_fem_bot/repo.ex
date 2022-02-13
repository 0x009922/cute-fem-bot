defmodule CuteFemBot.Repo do
  use Ecto.Repo,
    otp_app: :cute_fem_bot,
    adapter: Ecto.Adapters.SQLite3
end
