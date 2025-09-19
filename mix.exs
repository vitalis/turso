defmodule Turso.MixProject do
  use Mix.Project

  @version "0.1.1"
  @description "Elixir client library for Turso Cloud Platform API"
  @source_url "https://github.com/vitalis/turso"

  def project do
    [
      app: :turso,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: @description,
      package: package(),
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.github": :test
      ]
    ]
  end

  # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Runtime dependencies
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      {:nimble_options, "~> 1.1"},

      # Development and test dependencies
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:git_ops, "~> 2.9.0", only: [:dev], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:plug, "~> 1.16", only: :test},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp package do
    [
      name: "turso",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      },
      maintainers: ["Vitaly Gorodetsky"]
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: ["README.md", "LICENSE"],
      groups_for_modules: [
        "API Modules": [
          Turso.Databases,
          Turso.Groups,
          Turso.Organizations,
          Turso.Organizations.Members,
          Turso.Organizations.Invites,
          Turso.Locations,
          Turso.Tokens,
          Turso.AuditLogs
        ],
        Internal: [
          Turso.Client,
          Turso.Schemas
        ]
      ]
    ]
  end
end
