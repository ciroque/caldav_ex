defmodule CaldavEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :caldav_ex,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:saxy, "~> 1.5"}      # Fast XML parser/generator
    ]
  end
end
