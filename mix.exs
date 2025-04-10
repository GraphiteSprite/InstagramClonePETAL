defmodule InstagramClone.MixProject do
  use Mix.Project

  def project do
    [
      app: :instagram_clone,
      version: "0.1.0",

      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {InstagramClone.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.0"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.10"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_live_view, "~> 0.20.0"},
      {:phoenix_live_reload, "~> 1.4", only: :dev},
      {:phoenix_live_dashboard, "~> 0.8.0"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      # Updated version
      {:bcrypt_elixir, "~> 3.0"},
      {:postgrex, ">= 0.0.0"},
      # Updated version
      {:floki, ">= 0.30.0", only: :test},
      # Updated version
      {:gettext, "~> 0.20"},
      # Updated version
      {:jason, "~> 1.4"},
      # Updated version
      {:plug_cowboy, "~> 2.6"},
      # Updated version
      {:timex, "~> 3.7"},
      # Updated version
      {:faker, "~> 0.17"},
      # Updated version
      {:mogrify, "~> 0.9.0"},
      {:petal_components, "~> 1.2"},
      {:heroicons, "~> 0.5.3"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "cmd npm install --prefix assets"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
