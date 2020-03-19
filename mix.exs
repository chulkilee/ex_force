defmodule ExForce.Mixfile do
  use Mix.Project

  @version "0.3.1-dev"

  def project do
    [
      app: :ex_force,
      version: @version,
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      package: package(),
      preferred_cli_env: ["test.all": :test],

      # dialyxir
      dialyzer: [
        plt_add_apps: [:tesla]
      ],

      # hex
      description: "Simple Elixir wrapper for Salesforce REST API",

      # ex_doc
      name: "ExForce",
      source_url: "https://github.com/chulkilee/ex_force",
      homepage_url: "https://github.com/chulkilee/ex_force",
      docs: [main: "ExForce"],

      # test
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:tesla, "~> 1.3"},
      {:jason, "~> 1.0"},
      # Docs
      {:inch_ex, "~> 2.0.0", only: :dev},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      # Lint
      {:credo, "~> 1.1", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false},
      # Testing
      {:bypass, "~> 1.0", only: :test},
      {:excoveralls, "~> 0.12", only: :test}
    ]
  end

  defp aliases do
    [
      "test.all": [
        "credo --strict",
        "dialyzer",
        "test"
      ]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/chulkilee/ex_force",
        "Changelog" => "https://github.com/chulkilee/ex_force/blob/master/CHANGELOG.md"
      },
      maintainers: ["Chulki Lee"]
    ]
  end
end
