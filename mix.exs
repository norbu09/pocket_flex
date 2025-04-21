defmodule PocketFlex.MixProject do
  use Mix.Project

  def project do
    [
      app: :pocket_flex,
      version: "0.1.0",
      elixir: ">= 1.14.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "An Elixir implementation of the PocketFlow agent framework",
      package: package(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {PocketFlex.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.29.0", only: :dev, runtime: false},
      {:dialyxir, ">= 1.3.0", only: [:dev], runtime: false},
      {:credo, ">= 1.7.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/yourusername/pocket_flex"
      }
    ]
  end

  defp docs do
    [
      main: "PocketFlex",
      source_url: "https://github.com/yourusername/pocket_flex",
      extras: ["README.md"]
    ]
  end
end
