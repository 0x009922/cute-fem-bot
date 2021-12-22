defmodule CuteFemBot.MixProject do
  use Mix.Project

  def project do
    [
      app: :cute_fem_bot,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {CuteFemBot.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:finch, "~> 0.10"},
      {:typed_struct, "~> 0.2.1"},
      {:yaml_elixir, "~> 2.8.0"},
      {:json, "~> 1.4"}
    ]
  end
end
