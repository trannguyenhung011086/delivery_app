defmodule DeliveryApp.Orders.DeliveryOption do
  use Ecto.Schema
  import Ecto.Changeset

  schema "delivery_options" do
    field :code, :string
    field :name, :string
    field :eta_days, :integer
    field :base_fee_cents, :integer
    field :active, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(delivery_option, attrs) do
    delivery_option
    |> cast(attrs, [:code, :name, :eta_days, :base_fee_cents, :active])
    |> validate_required([:code, :name, :eta_days, :base_fee_cents, :active])
    |> validate_number(:eta_days, greater_than_or_equal_to: 0)
    |> validate_number(:base_fee_cents, greater_than_or_equal_to: 0)
    |> unique_constraint(:code)
  end
end
