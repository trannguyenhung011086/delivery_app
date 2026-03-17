defmodule DeliveryApp.Orders.TrackingEvent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tracking_events" do
    field :status, :string
    field :description, :string
    field :occurred_at, :utc_datetime

    belongs_to :order, DeliveryApp.Orders.Order

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(tracking_event, attrs) do
    tracking_event
    |> cast(attrs, [:status, :description, :occurred_at])
    |> validate_required([:status, :description, :occurred_at])
    |> foreign_key_constraint(:order_id)
  end
end
