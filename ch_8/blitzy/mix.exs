defmodule Blitzy.Mixfile do
  use Mix.Project

  def project do
    [
      app: :blitzy,
      version: "0.0.1",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      escript: [main_module: Blitzy.CLI],
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
      {:httpoison, "~> 0.9.0"},
      {:timex, "~> 3.0"},
      {:tzdata, "~> 0.1.8", override: true}
    ]
  end
end