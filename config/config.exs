import Config

is_prod? = Mix.env() == :prod

if is_prod? do
  config :logger,
    backends: [:console],
    compile_time_purge_matching: [[level_lower_than: :info]]

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

config :plug_cowboy,
  log_exceptions_with_status_code: [400..599]
