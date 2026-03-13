defmodule DeliveryApp.Repo do
  use Ecto.Repo,
    otp_app: :delivery_app,
    adapter: Ecto.Adapters.Postgres
end
