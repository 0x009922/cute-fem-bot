import Config

# Ecto
config :cute_fem_bot,
  ecto_repos: [CuteFemBot.Repo]

# Default database
config :cute_fem_bot, CuteFemBot.Repo, database: "data/main.db", auto_vacuum: :incremental

# Time zones
config :elixir, :time_zone_database, Zoneinfo.TimeZoneDatabase

import_config "#{config_env()}.exs"
