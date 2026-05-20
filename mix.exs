defmodule CaldavEx.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/ciroque/caldav_ex"

  def project do
    [
      app: :caldav_ex,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "CalDAVEx",
      source_url: @source_url,
      dialyzer: dialyzer()
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:saxy, "~> 1.5"},
      {:ical, "~> 2.0"},
      {:tz, "~> 0.28.1"},
      {:bypass, "~> 2.1", only: :test},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    "Elixir CalDAV client library for calendar and event management"
  end

  defp package do
    [
      name: "caldav_ex",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      },
      maintainers: ["Steve Wagner"]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      plt_add_apps: [:mix, :ex_unit]
    ]
  end
end
