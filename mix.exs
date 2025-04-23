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
      {:credo, ">= 1.7.0", only: [:dev, :test], runtime: false},
      {:meck, ">= 0.9.2", only: :test},
      {:phoenix_pubsub, ">= 2.1.0"},
      {:telemetry, ">= 1.0.0"}
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
      extras: [
        "README.md",
        "guides/state_storage.md",
        "guides/dsl_guide.md",
        "guides/execution_models.md"
      ],
      groups_for_extras: [
        Guides: ~r/guides\/.?/
      ],
      groups_for_modules: [
        Core: [
          PocketFlex,
          PocketFlex.Flow,
          PocketFlex.Node
        ],
        "State Storage": [
          PocketFlex.StateStorage,
          PocketFlex.StateStorage.ETS
        ],
        "Async Processing": [
          PocketFlex.AsyncNode,
          PocketFlex.AsyncBatchNode,
          PocketFlex.AsyncParallelBatchNode,
          PocketFlex.AsyncBatchFlow,
          PocketFlex.AsyncParallelBatchFlow
        ],
        DSL: [
          PocketFlex.DSL
        ],
        Examples: ~r/PocketFlex\.Examples\..?/
      ]
    ]
  end
end
