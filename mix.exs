defmodule ExForce.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ex_force,
      version: "0.1.0",
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
      docs: [
        main: "ExForce",
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.16", only: :dev, runtime: false},
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/chulkilee/ex_force"},
      maintainers: ["Chulki Lee"],
    ]
  end
end
