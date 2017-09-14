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
      extra_applications: [:logger],
      mod: {ExForce.Application, []}
    ]
  end

  defp deps do
    [
      {:httpoison, "~> 0.13"},
      {:poison, "~> 3.1"},
      {:bypass, "~> 0.8", only: :test},
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.7", only: :test},
      {:ex_doc, "~> 0.16", only: :dev, runtime: false},
      {:inch_ex, "~> 0.5", only: :docs}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/chulkilee/ex_force"},
      maintainers: ["Chulki Lee"]
    ]
  end
end
