defmodule LargePhoenixApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :large_phoenix_app,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {LargePhoenixApp.Application, []}
    ]
  end

  defp deps do
    [
      # No external dependencies for test project
      # This simulates the modules without requiring actual Phoenix/Ecto
    ]
  end
end
