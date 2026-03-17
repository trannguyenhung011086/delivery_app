defmodule DeliveryAppWeb.Router do
  use DeliveryAppWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", DeliveryAppWeb do
    pipe_through :api

    get "/health", HealthController, :show
    resources "/orders", OrdersController, only: [:index, :show, :create]
    resources "/delivery_options", DeliveryOptionsController, only: [:index]
    resources "/tracking_events", TrackingEventsController, only: [:create]
  end
end
