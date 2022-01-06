import Config

is_prod? = Mix.env() == :prod

logger_compile_time_purge_matching =
  if is_prod? do
    [
      [level_lower_than: :info]
    ]
  else
    []
  end

config :logger,
  backends: [:console],
  compile_time_purge_matching: logger_compile_time_purge_matching

config :logger, :console,
  format: "$date $time $metadata[$level] $levelpad$message\n",
  metadata: [:file, :line, :mfa, :crash_reason, :pid, :registered_name]
