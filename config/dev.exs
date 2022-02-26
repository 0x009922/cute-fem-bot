config :logger,
  backends: [:console]

config :logger, :console,
  format: "$date $time $metadata[$level] $levelpad$message\n",
  metadata: [:mfa, :crash_reason]
