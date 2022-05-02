defmodule CuteFemBot.MixProject do
  use Mix.Project

  def project do
    [
      app: :cute_fem_bot,
      version: "1.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      preferred_cli_env: preferred_cli_env()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: if(Mix.env() == :test, do: [], else: {CuteFemBot.Application, []})
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:finch, "~> 0.10"},
      {:typed_struct, "~> 0.2.1"},
      {:yaml_elixir, "~> 2.8.0"},
      {:jason, "~> 1.3"},
      {:crontab, "~> 1.1.10"},
      {:plug_cowboy, "~> 2.0"},
      {:zoneinfo, "~> 0.1.0"},
      {:ecto_sqlite3, "~> 0.7.3"},
      {:cachex, "~> 3.4"},
      {:elixir_uuid, "~> 1.2"},
      {:phoenix, "~> 1.6.6"},
      {:cors_plug, "~> 3.0"}
    ]
  end

  defp aliases() do
    [
      test_integration: [
        "ecto.drop",
        "ecto.create",
        "ecto.migrate --quiet",
        "test --no-start --only integration"
      ],
      test_unit: [
        "test --no-start"
      ]
    ]
  end

  defp preferred_cli_env() do
    [
      test_integration: :test,
      test_unit: :test
    ]
  end
end
