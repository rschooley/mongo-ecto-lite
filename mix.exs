defmodule MongoEctoLite.MixProject do
  use Mix.Project

  def project do
    [
      app: :mongodb_ecto_lite,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:ecto, "~> 3.7"},
      {:mongodb_driver, "~> 0.9.1"}
    ]
  end
end
