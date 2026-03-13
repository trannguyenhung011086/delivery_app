import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :delivery_app, DeliveryApp.Repo,
  url: System.get_env("DATABASE_URL") || "ecto://postgres:postgres@localhost/delivery_app_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :delivery_app, DeliveryAppWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "qgYhLZIEXHJ1CqN2vVup5PVh8UY0tedHHqqV79qbRqJmTtpON2ofCfI2fNekWan1",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
