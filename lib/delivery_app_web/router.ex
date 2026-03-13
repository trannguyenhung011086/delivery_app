defmodule DeliveryAppWeb.Router do
  use DeliveryAppWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", DeliveryAppWeb do
    pipe_through :api

    get "/health", HealthController, :show
  end
end
