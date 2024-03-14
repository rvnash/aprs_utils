defmodule AprsUtils.MixProject do
  use Mix.Project

  def project do
    [
      app: :aprs_utils,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # Docs
      name: "APRSUtils",
      source_url: "https://github.com/rvnash/aprs_utils",
      docs: [
        # The main page in the docs
        main: "APRSUtils",
        extras: ["README.md"]
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
