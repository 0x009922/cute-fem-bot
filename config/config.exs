import Config

is_prod? = Mix.env() == :prod

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

config :elixir, :time_zone_database, Zoneinfo.TimeZoneDatabase

config :plug_cowboy,
  log_exceptions_with_status_code: [400..599]
