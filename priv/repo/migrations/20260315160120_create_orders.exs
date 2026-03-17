defmodule DeliveryApp.Repo.Migrations.CreateOrders do
  use Ecto.Migration

  def change do
    create table(:orders) do
      add :customer_name, :string, null: false
      add :address, :string, null: false
      add :postcode, :string, null: false
      add :total_cents, :integer, null: false
      add :status, :string, null: false, default: "CREATED"
      add :delivery_option_id, references(:delivery_options, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:orders, [:delivery_option_id])
    create index(:orders, [:status])
  end
end
