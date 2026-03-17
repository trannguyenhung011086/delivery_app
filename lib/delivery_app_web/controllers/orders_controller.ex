defmodule DeliveryAppWeb.OrdersController do
  use DeliveryAppWeb, :controller
  alias DeliveryApp.Orders

  def create(conn, params) do
    case Orders.create_order_with_delivery(params) do
      {:ok, order} -> conn |> put_status(:created) |> json(%{data: order})
      {:error, :invalid_delivery_option} -> conn |> put_status(:bad_request) |> json(%{error: "Invalid delivery option"})
      {:error, changeset} -> conn |> put_status(:unprocessable_entity) |> json(%{errors: "Validation failed", details: changeset_errors(changeset)})
      {:error, reason} -> conn |> put_status(:internal_server_error) |> json(%{error: reason})
    end
  end

  def show(conn, %{"id" => id}) do
    case Orders.get_order!(id) do
      order -> json(conn, %{data: order})
      nil -> conn |> put_status(:not_found) |> json(%{error: "Order not found"})
    end
  end

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
