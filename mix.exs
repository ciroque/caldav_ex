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
      {:saxy, "~> 1.5"},      # Fast XML parser/generator
      {:ical, "~> 2.0"},
      {:tz, "~> 0.28.1"},
      {:bypass, "~> 2.1", only: :test}
    ]
  end
end
