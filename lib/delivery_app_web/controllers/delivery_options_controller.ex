defmodule DeliveryAppWeb.DeliveryOptionsController do
	use DeliveryAppWeb, :controller
	alias DeliveryApp.Orders

	def index(conn, _params) do
	  delivery_options = Orders.list_active_delivery_options()
		json(conn, %{data: delivery_options})
	end
end
