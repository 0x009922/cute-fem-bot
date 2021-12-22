import Config

# Our Logger general configuration
config :logger,
  backends: [:console]

# Our Console Backend-specific configuration
config :logger, :console,
  format: "$date $time $metadata[$level] $levelpad$message\n",
  metadata: [:file, :line, :mfa, :crash_reason, :pid, :registered_name]
