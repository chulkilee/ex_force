defmodule ExForce.Mixfile do
  use Mix.Project

  @version "0.1.1-dev"

  def project do
    [
      app: :ex_force,
      version: @version,
      elixir: "~> 1.5",
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
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:tesla, "~> 1.0.0"},
      {:jason, "~> 1.0"},
      {:bypass, "~> 0.8", only: :test},
      {:credo, "~> 0.9", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.8", only: :test},
      {:ex_doc, "~> 0.18", only: :docs, runtime: false},
      {:inch_ex, "~> 0.5", only: :docs}
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
