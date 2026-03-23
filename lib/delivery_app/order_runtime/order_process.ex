defmodule DeliveryApp.OrderRuntime.OrderProcess do
  use GenServer
  require Logger

  alias DeliveryApp.{Repo, OrderRuntime}
  alias DeliveryApp.Orders
  alias DeliveryApp.Orders.{Order, OrderState}

  # --- Client API ---

  def start_link(order_id) do
    GenServer.start_link(__MODULE__, order_id, name: OrderRuntime.via_tuple(order_id))
  end

  # --- Server Callbacks ---

  @impl true
  def init(order_id) do
    Logger.info("OrderProcess starting for order #{order_id}")

    case Repo.get(Order, order_id) do
      nil -> {:stop, :order_not_found}
      order ->
        state = %{
          order_id: order.id,
          status: order.status,
          started_at: Date.utc_today()
        }
        {:ok, state}
    end
  end

  @impl true
  def handle_call({:transition, new_status, description}, _from, state) do
    case OrderState.allowed_transition?(state.status, new_status) do
      true ->
        # Persist to DB
        order = Repo.get!(Order, state.order_id)

        {:ok, _order} =
          order
          |> Ecto.Changeset.change(status: new_status)
          |> Repo.update()

        {:ok, _event} =
          Orders.create_tracking_event(
            order,
            new_status,
            description || "Transitioned to #{new_status}"
          )

        new_state = %{state | status: new_status}
        Logger.info("Order #{state.order_id}: #{state.status} -> #{new_status}")

        {:reply, {:ok, new_state}, new_state}

      false ->
        Logger.warning(
          "Order #{state.order_id}: invalid transition #{state.status} -> #{new_status}"
        )

        {:reply, {:error, :invalid_transition}, state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("OrderProcess #{state.order_id} terminating: #{inspect(reason)}")
    :ok
  end
end
