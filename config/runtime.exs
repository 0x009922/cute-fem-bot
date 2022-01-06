import Config

config :cute_fem_bot,
  port: System.get_env("PORT", "3000"),
  public_path: System.get_env("PUBLIC_PATH")
  update_approach: System.get_env("UPDATE_APPROACH")
