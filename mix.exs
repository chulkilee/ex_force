defmodule ExForce.Mixfile do
  use Mix.Project

  @version "0.4.1-dev"

  def project do
    [
      app: :ex_force,
      version: @version,
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),

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
      {:bypass, "~> 2.1", only: :test},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: :dev, runtime: false},
      {:excoveralls, "~> 0.14", only: :test},
      {:ex_doc, "~> 0.24", only: :dev, runtime: false},
      {:inch_ex, "~> 2.0", only: [:dev, :test]}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/chulkilee/ex_force",
        "Changelog" => "https://github.com/chulkilee/ex_force/blob/main/CHANGELOG.md"
      },
      maintainers: ["Chulki Lee"]
    ]
  end
end
