import Config

config :logger,
  backends: [:console],
  format: "$date $time $metadata[$level] $levelpad$message\n",
  metadata: [:file, :line, :mfa, :crash_reason, :pid, :registered_name],
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]
