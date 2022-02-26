config :logger,
  backends: [:console],
  level: :info

config :logger, :console,
  format: "$date $time $metadata[$level] $levelpad$message\n",
  metadata: [:file, :line, :mfa, :crash_reason, :pid, :registered_name]
