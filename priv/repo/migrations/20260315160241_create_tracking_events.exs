defmodule DeliveryApp.Repo.Migrations.CreateTrackingEvents do
  use Ecto.Migration

  def change do
    create table(:tracking_events) do
      add :status, :string, null: false
      add :description, :string
      add :occurred_at, :utc_datetime, null: false, default: fragment("CURRENT_TIMESTAMP")
      add :order_id, references(:orders, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:tracking_events, [:order_id])
  end
end
