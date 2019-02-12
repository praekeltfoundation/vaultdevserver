defmodule Vaultdevserver.MixProject do
  use Mix.Project

  def project do
    [
      app: :vaultdevserver,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.json": :test,
        "coveralls.detail": :test,
        credo: :test,
        format: :test,
        release: :prod
      ],
      dialyzer: dialyzer(),
      package: package(),
      description: description(),
      name: "VaultDevServer",
      source_url: "https://github.com/praekeltfoundation/vaultdevserver"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" for examples and options.
  defp deps do
    [
      # Dev/test/build tools.
      {:excoveralls, "~> 0.8", only: :test},
      {:dialyxir, "~> 1.0.0-rc.4", only: :dev, runtime: false},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      # Doc tools.
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:inch_ex, "~> 2.0", only: :dev, runtime: false}
    ]
  end

  defp dialyzer do
    [
      # These are most of the optional warnings in the dialyzer docs. We skip
      # :error_handling (because we don't care about functions that only raise
      # exceptions) and two others that are intended for developing dialyzer
      # itself.
      flags: [
        :unmatched_returns,
        # The dialyzer docs indicate that the race condition check can
        # sometimes take a whole lot of time.
        :race_conditions,
        :underspecs
      ]
    ]
  end

  defp description do
    "Test applications against a HashiCorp Vault dev server"
  end

  defp package do
    [
      licenses: ["BSD 3-Clause"],
      links: %{"GitHub" => "https://github.com/praekeltfoundation/vaultdevserver"}
    ]
  end
end
