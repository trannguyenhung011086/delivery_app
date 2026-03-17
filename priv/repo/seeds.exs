# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     DeliveryApp.Repo.insert!(%DeliveryApp.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias DeliveryApp.Repo
alias DeliveryApp.Orders.DeliveryOption

Repo.insert!(%DeliveryOption{
  code: "STANDARD",
  name: "Standard Delivery",
  eta_days: 3,
  base_fee_cents: 500,
  active: true
})

Repo.insert!(%DeliveryOption{
  code: "EXPRESS",
  name: "Express Delivery",
  eta_days: 1,
  base_fee_cents: 1500,
  active: true
})
