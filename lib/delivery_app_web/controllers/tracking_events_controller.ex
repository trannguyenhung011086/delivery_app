defmodule DeliveryAppWeb.TrackingEventsController do
  use DeliveryAppWeb, :controller
  alias DeliveryApp.Orders

  def create(conn, %{"order_id" => order_id} = params) do
    order = Repo.get!(Order, order_id)

    case Orders.create_tracking_event(order, params["status"], params["description"]) do
      {:ok, event} -> conn |> put_status(:created) |> json(%{data: tracking_event_json(event)})
      {:error, changeset} -> conn |> put_status(:unprocessable_entity) |> json(%{errors: "Validation failed", details: changeset_errors(changeset)})
      {:error, reason} -> conn |> put_status(:internal_server_error) |> json(%{error: reason})
    end
  end

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp tracking_event_json(event) do
    %{
      id: event.id,
      status: event.status,
      description: event.description,
      occurred_at: event.occurred_at
    }
  end
end
