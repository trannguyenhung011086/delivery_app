defmodule DeliveryApp.OrderRuntime do
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
