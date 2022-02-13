import Config

is_prod? = Mix.env() == :prod
is_test? = Mix.env() == :test

# Ecto

if is_test? do
  config :cute_fem_bot, CuteFemBot.Repo, database: "data/test.db", pool: Ecto.Adapters.SQL.Sandbox
else
  config :cute_fem_bot, CuteFemBot.Repo, database: "data/sqlite.db", auto_vacuum: :incremental
end

config :cute_fem_bot,
  ecto_repos: [CuteFemBot.Repo]

# Logger

if is_prod? do
  config :logger,
    backends: [:console],
    level: :info

  config :logger, :console,
    format: "$date $time $metadata[$level] $levelpad$message\n",
    metadata: [:file, :line, :mfa, :crash_reason, :pid, :registered_name]
else
  config :logger,
    backends: [:console]

  config :logger, :console,
    format: "$date $time $metadata[$level] $levelpad$message\n",
    metadata: [:mfa, :crash_reason]
end

# Time zones

config :elixir, :time_zone_database, Zoneinfo.TimeZoneDatabase

# cowboy

config :plug_cowboy,
  log_exceptions_with_status_code: [400..599]
