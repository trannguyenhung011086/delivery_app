defmodule DeliveryApp.Orders.OrderState do
	@type status :: String.t()

	@spec allowed_transition?(status(), status()) :: boolean()

	def allowed_transition?("CREATED", "PICKED_UP"), do: true

	def allowed_transition?("PICKED_UP", "IN_TRANSIT"), do: true

  def allowed_transition?("IN_TRANSIT", "DELIVERED"), do: true

  def allowed_transition?(from, "CANCELLED") when from in ["CREATED", "PICKED_UP"], do: true

  def allowed_transition?(_from, _to), do: false
end
