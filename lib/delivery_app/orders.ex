defmodule DeliveryApp.Orders do
	import Ecto.Query, warn: false
	alias DeliveryApp.Repo
	alias DeliveryApp.Orders.{Order, DeliveryOption, TrackingEvent}

	def list_active_delivery_options do
    DeliveryOption
      |> where([d], d.active == true)
      |> order_by([d], asc: d.eta_days)
      |> Repo.all()
	end

	def get_order!(id) do
  	Order
      |> Repo.get!(id)
      |> Repo.preload([:delivery_option, :tracking_events])
	end

	def create_order_with_delivery(attrs) do
    Repo.transaction(fn ->
      with {:ok, delivery_option} <- fetch_delivery_option(attrs["delivery_option_code"]),
           {:ok, order} <- create_order(attrs, delivery_option),
           {:ok, _event} <- create_tracking_event(order, "CREATED", "Order created") do
        order
          |> Repo.preload([:delivery_option, :tracking_events])
      else
        {:error, changeset} -> Repo.rollback(changeset)
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp fetch_delivery_option(code) do
    case Repo.get_by(DeliveryOption, code: code, active: true) do
      nil -> {:error, :invalid_delivery_option}
      opt -> {:ok, opt}
    end
  end

  defp create_order(attrs, %DeliveryOption{id: delivery_option_id}) do
    %Order{}
      |> Order.changeset(Map.put(attrs, "delivery_option_id", delivery_option_id))
      |> Repo.insert()
  end

  def create_tracking_event(%Order{id: order_id}, status, description) do
    %TrackingEvent{}
      |> TrackingEvent.changeset(%{
          "order_id" => order_id,
          "status" => status,
          "description" => description,
          "occurred_at" => DateTime.utc_now()
        })
      |> Repo.insert()
  end
end
