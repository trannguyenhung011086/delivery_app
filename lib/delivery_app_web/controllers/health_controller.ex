defmodule DeliveryAppWeb.HealthController do
  @moduledoc """
  Simple health check endpoint returning a JSON 200 response.
  """

  use DeliveryAppWeb, :controller

  @doc "GET /api/health"
  def show(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
