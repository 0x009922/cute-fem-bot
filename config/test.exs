import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :cute_fem_bot, CuteFemBotWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "NyK1tqlTVQY5JVwjWghug26lhndJFNHA0tkjJbTpenJ8gBDhZeg33+rYorP+zU/O",
  server: false

# use special test database with sandbox pool
config :cute_fem_bot, CuteFemBot.Repo, database: "data/test.db", pool: Ecto.Adapters.SQL.Sandbox

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
