defmodule AprsUtils.MixProject do
  use Mix.Project

  def project do
    [
      app: :aprs_utils,
      version: "0.1.0",
      elixir: "~> 1.16",
      description: "APRS Utilities",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # Docs
      name: "AprsUtils",
      source_url: "https://github.com/rvnash/aprs_utils",
      docs: [
        main: "readme",
        extras: ["README.md"]
      ],
      package: [
        name: "aprs_utils",
        files: ~w(lib .formatter.exs mix.exs README.md LICENSE),
        licenses: ["MIT"],
        links: %{"GitHub" => "https://github.com/rvnash/aprs_utils"}
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end
end
