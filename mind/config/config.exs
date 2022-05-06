import Config

# Ecto
config :cute_fem_bot,
  ecto_repos: [CuteFemBot.Repo]

# Default database
config :cute_fem_bot, CuteFemBot.Repo, database: "data/main.db", auto_vacuum: :incremental

# Time zones
config :elixir, :time_zone_database, Zoneinfo.TimeZoneDatabase

# Base endpoint config
config :cute_fem_bot, CuteFemBotWeb.Endpoint, url: [host: "localhost"]

# Setup JSON lib for Phoenix
config :phoenix, :json_library, Jason

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

import_config "#{config_env()}.exs"
