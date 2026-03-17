defmodule DeliveryAppWeb.DeliveryOptionsController do
	use DeliveryAppWeb, :controller
	alias DeliveryApp.Orders

	def index(conn, _params) do
	  delivery_options = Orders.list_active_delivery_options()
		json(conn, %{data: delivery_options_json(delivery_options)})
	end

	defp delivery_options_json(delivery_options) do
		Enum.map(delivery_options, fn opt ->
      %{
        code: opt.code,
        name: opt.name,
        eta_days: opt.eta_days,
        base_fee_cents: opt.base_fee_cents
      }
    end)
	end
end
