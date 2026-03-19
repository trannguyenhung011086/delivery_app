# Guide 02 — Improving the App with OTP

> **Goal:** Add a supervised GenServer per order with validated state transitions.
> **Time:** ~8 hours across 2 weeks
> **Prereq:** Guide 01 completed, app running in Docker

---

## 1. Define the Order State Machine

A pure module — no processes, no DB, just logic.

```elixir
# lib/delivery_app/orders/order_state.ex
defmodule DeliveryApp.Orders.OrderState do
  @moduledoc """
  Pure state machine for order status transitions.
  No side effects — just answers "is this transition allowed?"
  """

  @type status :: String.t()

  @spec allowed_transition?(status(), status()) :: boolean()
  def allowed_transition?(from, to)

  def allowed_transition?("CREATED", "PICKED_UP"), do: true
  def allowed_transition?("PICKED_UP", "IN_TRANSIT"), do: true
  def allowed_transition?("IN_TRANSIT", "DELIVERED"), do: true

  # Cancellation — only before shipping
  def allowed_transition?(from, "CANCELLED") when from in ["CREATED", "PICKED_UP"], do: true

  # Everything else is invalid
  def allowed_transition?(_from, _to), do: false
end
```

---

## 2. Add Registry + DynamicSupervisor

Edit your application supervision tree:

```elixir
# lib/delivery_app/application.ex
defmodule DeliveryApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      DeliveryApp.Repo,
      DeliveryAppWeb.Telemetry,
      {Phoenix.PubSub, name: DeliveryApp.PubSub},
      DeliveryAppWeb.Endpoint,
      # OTP layer — add these two:
      {Registry, keys: :unique, name: DeliveryApp.OrderRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: DeliveryApp.OrderSupervisor}
    ]

    opts = [strategy: :one_for_one, name: DeliveryApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    DeliveryAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
```

---

## 3. Create the OrderRuntime Module

This is the public API for managing order processes.

```elixir
# lib/delivery_app/order_runtime.ex
defmodule DeliveryApp.OrderRuntime do
  @moduledoc """
  Manages order processes. Starts, finds, and routes commands
  to per-order GenServers.
  """

  alias DeliveryApp.OrderRuntime.OrderProcess

  @registry DeliveryApp.OrderRegistry
  @supervisor DeliveryApp.OrderSupervisor

  def via_tuple(order_id) do
    {:via, Registry, {@registry, order_id}}
  end

  def start_order_process(order_id) do
    spec = {OrderProcess, order_id}
    DynamicSupervisor.start_child(@supervisor, spec)
  end

  def ensure_started(order_id) do
    case Registry.lookup(@registry, order_id) do
      [] -> start_order_process(order_id)
      [{_pid, _}] -> :ok
    end
  end

  def transition(order_id, new_status, description \\ nil) do
    ensure_started(order_id)
    GenServer.call(via_tuple(order_id), {:transition, new_status, description})
  end

  def get_state(order_id) do
    ensure_started(order_id)
    GenServer.call(via_tuple(order_id), :get_state)
  end
end
```

---

## 4. Implement the OrderProcess GenServer

```elixir
# lib/delivery_app/order_runtime/order_process.ex
defmodule DeliveryApp.OrderRuntime.OrderProcess do
  @moduledoc """
  A GenServer that manages the lifecycle of a single order.
  Loads state from DB on init, validates transitions in memory,
  persists changes back to DB.
  """
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
      nil ->
        {:stop, :order_not_found}

      order ->
        state = %{
          order_id: order.id,
          status: order.status,
          started_at: DateTime.utc_now()
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
```

---

## 5. Update the Orders Context

Add a function that routes through OTP:

```elixir
# Add to lib/delivery_app/orders.ex

def transition_order(order_id, new_status, description \\ nil) do
  DeliveryApp.OrderRuntime.transition(order_id, new_status, description)
end
```

---

## 6. Add a Transitions Controller

```elixir
# lib/delivery_app_web/controllers/order_transitions_controller.ex
defmodule DeliveryAppWeb.OrderTransitionsController do
  use DeliveryAppWeb, :controller
  alias DeliveryApp.Orders

  def create(conn, %{"id" => order_id, "status" => new_status} = params) do
    description = Map.get(params, "description")

    case Orders.transition_order(String.to_integer(order_id), new_status, description) do
      {:ok, state} ->
        json(conn, %{
          order_id: state.order_id,
          status: state.status,
          message: "Transition successful"
        })

      {:error, :invalid_transition} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Invalid status transition"})
    end
  end
end
```

Add the route:

```elixir
# In router.ex, inside the /api scope:
post "/orders/:id/transitions", OrderTransitionsController, :create
```

---

## 7. Test It

```bash
# Create an order first (from Guide 01), then:

# Valid transition: CREATED -> PICKED_UP
curl -X POST http://localhost:4000/api/orders/1/transitions \
  -H "Content-Type: application/json" \
  -d '{"status": "PICKED_UP", "description": "Picked up from warehouse"}'

# Valid: PICKED_UP -> IN_TRANSIT
curl -X POST http://localhost:4000/api/orders/1/transitions \
  -H "Content-Type: application/json" \
  -d '{"status": "IN_TRANSIT", "description": "Handed to carrier"}'

# Invalid: IN_TRANSIT -> PICKED_UP (should return 422)
curl -X POST http://localhost:4000/api/orders/1/transitions \
  -H "Content-Type: application/json" \
  -d '{"status": "PICKED_UP"}'

# Valid: IN_TRANSIT -> DELIVERED
curl -X POST http://localhost:4000/api/orders/1/transitions \
  -H "Content-Type: application/json" \
  -d '{"status": "DELIVERED", "description": "Left at front door"}'

# Check the order — should show full tracking history
curl http://localhost:4000/api/orders/1
```

---

## 8. Crash Testing

Try these in IEx to see supervision in action:

```bash
docker compose exec app iex -S mix
```

```elixir
# Start a process for order 1
DeliveryApp.OrderRuntime.ensure_started(1)

# Find its PID
[{pid, _}] = Registry.lookup(DeliveryApp.OrderRegistry, 1)

# Kill it
Process.exit(pid, :kill)

# Wait a moment, then try to transition — supervisor restarts it
DeliveryApp.OrderRuntime.transition(1, "PICKED_UP")
```

---

## 9. Write Tests

```elixir
# test/delivery_app/orders/order_state_test.exs
defmodule DeliveryApp.Orders.OrderStateTest do
  use ExUnit.Case, async: true
  alias DeliveryApp.Orders.OrderState

  describe "allowed_transition?/2" do
    test "allows CREATED -> PICKED_UP" do
      assert OrderState.allowed_transition?("CREATED", "PICKED_UP")
    end

    test "allows PICKED_UP -> IN_TRANSIT" do
      assert OrderState.allowed_transition?("PICKED_UP", "IN_TRANSIT")
    end

    test "allows IN_TRANSIT -> DELIVERED" do
      assert OrderState.allowed_transition?("IN_TRANSIT", "DELIVERED")
    end

    test "allows cancellation from CREATED" do
      assert OrderState.allowed_transition?("CREATED", "CANCELLED")
    end

    test "allows cancellation from PICKED_UP" do
      assert OrderState.allowed_transition?("PICKED_UP", "CANCELLED")
    end

    test "rejects DELIVERED -> PICKED_UP" do
      refute OrderState.allowed_transition?("DELIVERED", "PICKED_UP")
    end

    test "rejects cancellation from IN_TRANSIT" do
      refute OrderState.allowed_transition?("IN_TRANSIT", "CANCELLED")
    end

    test "rejects cancellation from DELIVERED" do
      refute OrderState.allowed_transition?("DELIVERED", "CANCELLED")
    end
  end
end
```

Run:

```bash
docker compose exec app mix test
```

---

## 10. Checkpoint

You should now have:

- [x] Pure state machine module (OrderState)
- [x] DynamicSupervisor + Registry in supervision tree
- [x] OrderProcess GenServer per order
- [x] OrderRuntime as routing layer
- [x] Transitions controller + route
- [x] Crash tested — supervisor restarts processes
- [x] Unit tests for state machine

**Next:** Guide 03 — Arc 1: End-to-End Workflow Design
