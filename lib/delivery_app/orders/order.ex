defmodule DeliveryApp.Orders.Order do
  use Ecto.Schema
  import Ecto.Changeset

  schema "orders" do
    field :customer_name, :string
    field :address, :string
    field :postcode, :string
    field :total_cents, :integer
    field :status, :string, default: "CREATED"

    belongs_to :delivery_option, DeliveryApp.Orders.DeliveryOption
    has_many :tracking_events, DeliveryApp.Orders.TrackingEvent

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(order, attrs) do
    order
    |> cast(attrs, [:customer_name, :address, :postcode, :total_cents, :status])
    |> validate_required([:customer_name, :address, :postcode, :total_cents, :status])
    |> validate_number(:total_cents, greater_than: 0)
    |> validate_inclusion(:status, ["CREATED", "PICKED_UP", "IN_TRANSIT", "DELIVERED", "CANCELLED"])
    |> assoc_constraint(:delivery_option)
  end
end
