defmodule DeliveryApp.Repo.Migrations.CreateDeliveryOptions do
  use Ecto.Migration

  def change do
    create table(:delivery_options) do
      add :code, :string, null: false
      add :name, :string, null: false
      add :eta_days, :integer, null: false
      add :base_fee_cents, :integer, null: false
      add :active, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:delivery_options, :code)
  end
end
