# Guide 01 — Tiny Phoenix Delivery API

> **Goal:** Get a working JSON API with schemas, a context module, and controllers.
> **Time:** ~8 hours across 2 weeks
> **Prereq:** Docker + Docker Compose installed

---

## 1. Project Setup with Docker

### 1.1 Create the Phoenix project (on your host machine first)

You need Elixir locally just to generate the project skeleton. After that,
everything runs in Docker.

```bash
# If you don't have Elixir locally yet:
brew install mise
mise use -g erlang@27
mise use -g elixir@1.17
mix archive.install hex phx_new

# Generate the project (API-only, no HTML/LiveView)
mix phx.new delivery_app --no-html --no-assets --no-live --no-mailer --no-dashboard
cd delivery_app
```

### 1.2 Add Docker files

Create these 3 files in the project root:

**Dockerfile**

```dockerfile
FROM elixir:1.17-otp-27-alpine

RUN apk add --no-cache build-base git

WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy mix files first for better layer caching
COPY mix.exs mix.lock ./
RUN mix deps.get

COPY . .
RUN mix compile

CMD ["mix", "phx.server"]
```

**docker-compose.yml**

```yaml
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: delivery_app_dev
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data

  app:
    build: .
    ports:
      - "4000:4000"
    volumes:
      - .:/app
      - deps:/app/deps
      - build:/app/_build
    environment:
      DATABASE_URL: ecto://postgres:postgres@db/delivery_app_dev
      MIX_ENV: dev
      PHX_HOST: localhost
    depends_on:
      - db
    stdin_open: true
    tty: true

volumes:
  pgdata:
  deps:
  build:
```

**.dockerignore**

```
_build/
deps/
.git/
.elixir_ls/
```

### 1.3 Configure the database for Docker

Edit `config/dev.exs` — update the Repo config to use the environment variable:

```elixir
# config/dev.exs
config :delivery_app, DeliveryApp.Repo,
  url: System.get_env("DATABASE_URL") || "ecto://postgres:postgres@localhost/delivery_app_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
```

Also edit `config/test.exs` for test database:

```elixir
config :delivery_app, DeliveryApp.Repo,
  url: System.get_env("DATABASE_URL") || "ecto://postgres:postgres@localhost/delivery_app_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10
```

### 1.4 Start everything

```bash
# Build and start containers
docker compose up -d

# Create the database
docker compose exec app mix ecto.create

# Verify it works
docker compose exec app mix phx.server
```

Visit `http://localhost:4000` — you should see a Phoenix welcome page.

### 1.5 Your development workflow

```bash
# Run mix commands inside the container:
docker compose exec app mix ecto.migrate
docker compose exec app mix test
docker compose exec app mix format

# Open IEx (interactive Elixir shell):
docker compose exec app iex -S mix

# View logs:
docker compose logs -f app

# Rebuild after changing Dockerfile:
docker compose up -d --build

# Stop everything:
docker compose down

# Stop and wipe database:
docker compose down -v
```

**Tip:** Your code is mounted via volumes, so edits in your editor appear
instantly in the container. No rebuild needed for code changes.

---

## 2. Generate Schemas

We'll model three things: **DeliveryOption**, **Order**, and **TrackingEvent**.

### 2.1 DeliveryOption

```bash
docker compose exec app mix phx.gen.schema Orders.DeliveryOption delivery_options \
  code:string \
  name:string \
  eta_days:integer \
  base_fee_cents:integer \
  active:boolean
```

Edit the generated migration to add constraints:

```elixir
# priv/repo/migrations/XXXX_create_delivery_options.exs
def change do
  create table(:delivery_options) do
    add :code, :string, null: false
    add :name, :string, null: false
    add :eta_days, :integer, null: false
    add :base_fee_cents, :integer, null: false
    add :active, :boolean, default: true, null: false

    timestamps()
  end

  create unique_index(:delivery_options, [:code])
end
```

### 2.2 Order

```bash
docker compose exec app mix phx.gen.schema Orders.Order orders \
  customer_name:string \
  address:string \
  postcode:string \
  total_cents:integer \
  status:string \
  delivery_option_id:references:delivery_options
```

Edit the migration:

```elixir
def change do
  create table(:orders) do
    add :customer_name, :string, null: false
    add :address, :string, null: false
    add :postcode, :string, null: false
    add :total_cents, :integer, null: false
    add :status, :string, null: false, default: "CREATED"
    add :delivery_option_id, references(:delivery_options, on_delete: :restrict), null: false

    timestamps()
  end

  create index(:orders, [:delivery_option_id])
  create index(:orders, [:status])
end
```

### 2.3 TrackingEvent

```bash
docker compose exec app mix phx.gen.schema Orders.TrackingEvent tracking_events \
  order_id:references:orders \
  status:string \
  description:string \
  occurred_at:utc_datetime
```

Edit the migration:

```elixir
def change do
  create table(:tracking_events) do
    add :order_id, references(:orders, on_delete: :delete_all), null: false
    add :status, :string, null: false
    add :description, :string
    add :occurred_at, :utc_datetime, null: false

    timestamps()
  end

  create index(:tracking_events, [:order_id])
end
```

### 2.4 Run migrations

```bash
docker compose exec app mix ecto.migrate
```

---

## 3. Schema Modules (Associations + Changesets)

### 3.1 DeliveryOption

```elixir
# lib/delivery_app/orders/delivery_option.ex
defmodule DeliveryApp.Orders.DeliveryOption do
  use Ecto.Schema
  import Ecto.Changeset

  schema "delivery_options" do
    field :code, :string
    field :name, :string
    field :eta_days, :integer
    field :base_fee_cents, :integer
    field :active, :boolean, default: true

    has_many :orders, DeliveryApp.Orders.Order

    timestamps()
  end

  def changeset(delivery_option, attrs) do
    delivery_option
    |> cast(attrs, [:code, :name, :eta_days, :base_fee_cents, :active])
    |> validate_required([:code, :name, :eta_days, :base_fee_cents])
    |> validate_number(:eta_days, greater_than: 0)
    |> validate_number(:base_fee_cents, greater_than_or_equal_to: 0)
    |> unique_constraint(:code)
  end
end
```

### 3.2 Order

```elixir
# lib/delivery_app/orders/order.ex
defmodule DeliveryApp.Orders.Order do
  use Ecto.Schema
  import Ecto.Changeset

  schema "orders" do
    field :customer_name, :string
    field :address, :string
    field :postcode, :string
    field :total_cents, :integer
    field :status, :string, default: "CREATED"

    belongs_to :delivery_option, DeliveryApp.Orders.DeliveryOption
    has_many :tracking_events, DeliveryApp.Orders.TrackingEvent

    timestamps()
  end

  def changeset(order, attrs) do
    order
    |> cast(attrs, [:customer_name, :address, :postcode, :total_cents, :status, :delivery_option_id])
    |> validate_required([:customer_name, :address, :postcode, :total_cents, :status])
    |> validate_number(:total_cents, greater_than: 0)
    |> validate_inclusion(:status, ~w(CREATED PICKED_UP IN_TRANSIT DELIVERED CANCELLED))
    |> foreign_key_constraint(:delivery_option_id)
  end
end
```

### 3.3 TrackingEvent

```elixir
# lib/delivery_app/orders/tracking_event.ex
defmodule DeliveryApp.Orders.TrackingEvent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tracking_events" do
    field :status, :string
    field :description, :string
    field :occurred_at, :utc_datetime

    belongs_to :order, DeliveryApp.Orders.Order

    timestamps()
  end

  def changeset(tracking_event, attrs) do
    tracking_event
    |> cast(attrs, [:order_id, :status, :description, :occurred_at])
    |> validate_required([:order_id, :status, :occurred_at])
    |> foreign_key_constraint(:order_id)
  end
end
```

---

## 4. Orders Context (Domain Logic)

```elixir
# lib/delivery_app/orders.ex
defmodule DeliveryApp.Orders do
  import Ecto.Query, warn: false
  alias DeliveryApp.Repo
  alias DeliveryApp.Orders.{Order, DeliveryOption, TrackingEvent}

  def list_active_delivery_options do
    DeliveryOption
    |> where([o], o.active == true)
    |> order_by([o], asc: o.eta_days)
    |> Repo.all()
  end

  def get_order!(id) do
    Order
    |> Repo.get!(id)
    |> Repo.preload([:delivery_option, :tracking_events])
  end

  def create_order_with_delivery(attrs) do
    Repo.transaction(fn ->
      with {:ok, delivery_option} <- fetch_delivery_option(attrs["delivery_option_code"]),
           {:ok, order} <- create_order(attrs, delivery_option),
           {:ok, _event} <- create_tracking_event(order, "CREATED", "Order created") do
        order
        |> Repo.preload([:delivery_option, :tracking_events])
      else
        {:error, changeset} -> Repo.rollback(changeset)
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp fetch_delivery_option(code) do
    case Repo.get_by(DeliveryOption, code: code, active: true) do
      nil -> {:error, :invalid_delivery_option}
      opt -> {:ok, opt}
    end
  end

  defp create_order(attrs, %DeliveryOption{id: delivery_option_id}) do
    %Order{}
    |> Order.changeset(Map.put(attrs, "delivery_option_id", delivery_option_id))
    |> Repo.insert()
  end

  def create_tracking_event(%Order{id: order_id}, status, description) do
    %TrackingEvent{}
    |> TrackingEvent.changeset(%{
      "order_id" => order_id,
      "status" => status,
      "description" => description,
      "occurred_at" => DateTime.utc_now()
    })
    |> Repo.insert()
  end
end
```

---

## 5. Router & Controllers (JSON API)

### 5.1 Router

```elixir
# lib/delivery_app_web/router.ex
defmodule DeliveryAppWeb.Router do
  use DeliveryAppWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", DeliveryAppWeb do
    pipe_through :api

    get  "/delivery_options", DeliveryOptionsController, :index
    post "/orders", OrdersController, :create
    get  "/orders/:id", OrdersController, :show
    post "/orders/:id/tracking_events", TrackingEventsController, :create
  end
end
```

### 5.2 DeliveryOptionsController

```elixir
# lib/delivery_app_web/controllers/delivery_options_controller.ex
defmodule DeliveryAppWeb.DeliveryOptionsController do
  use DeliveryAppWeb, :controller
  alias DeliveryApp.Orders

  def index(conn, _params) do
    options = Orders.list_active_delivery_options()

    json(conn, %{
      data:
        Enum.map(options, fn opt ->
          %{
            code: opt.code,
            name: opt.name,
            eta_days: opt.eta_days,
            base_fee_cents: opt.base_fee_cents
          }
        end)
    })
  end
end
```

### 5.3 OrdersController

```elixir
# lib/delivery_app_web/controllers/orders_controller.ex
defmodule DeliveryAppWeb.OrdersController do
  use DeliveryAppWeb, :controller
  alias DeliveryApp.Orders

  def create(conn, params) do
    case Orders.create_order_with_delivery(params) do
      {:ok, order} ->
        conn
        |> put_status(:created)
        |> json(order_json(order))

      {:error, :invalid_delivery_option} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Invalid delivery option"})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Validation error", details: changeset_errors(changeset)})

      {:error, _reason} ->
        send_resp(conn, 500, "")
    end
  end

  def show(conn, %{"id" => id}) do
    order = Orders.get_order!(id)
    json(conn, order_json(order))
  end

  defp order_json(order) do
    %{
      id: order.id,
      customer_name: order.customer_name,
      address: order.address,
      postcode: order.postcode,
      total_cents: order.total_cents,
      status: order.status,
      delivery_option: %{
        code: order.delivery_option.code,
        name: order.delivery_option.name,
        eta_days: order.delivery_option.eta_days,
        base_fee_cents: order.delivery_option.base_fee_cents
      },
      tracking_events:
        Enum.map(order.tracking_events, fn ev ->
          %{
            status: ev.status,
            description: ev.description,
            occurred_at: ev.occurred_at
          }
        end)
    }
  end

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
```

### 5.4 TrackingEventsController

```elixir
# lib/delivery_app_web/controllers/tracking_events_controller.ex
defmodule DeliveryAppWeb.TrackingEventsController do
  use DeliveryAppWeb, :controller
  alias DeliveryApp.{Orders, Repo}
  alias DeliveryApp.Orders.Order

  def create(conn, %{"id" => order_id} = params) do
    order = Repo.get!(Order, order_id)

    case Orders.create_tracking_event(order, params["status"], params["description"]) do
      {:ok, event} ->
        json(conn, %{
          status: event.status,
          description: event.description,
          occurred_at: event.occurred_at
        })

      {:error, _changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Validation error"})
    end
  end
end
```

---

## 6. Seed Delivery Options

```elixir
# priv/repo/seeds.exs
alias DeliveryApp.Repo
alias DeliveryApp.Orders.DeliveryOption

Repo.insert!(%DeliveryOption{
  code: "STANDARD",
  name: "Standard Delivery",
  eta_days: 3,
  base_fee_cents: 500,
  active: true
})

Repo.insert!(%DeliveryOption{
  code: "EXPRESS",
  name: "Express Delivery",
  eta_days: 1,
  base_fee_cents: 1200,
  active: true
})
```

Run:

```bash
docker compose exec app mix run priv/repo/seeds.exs
```

---

## 7. Test the API

```bash
# Start the server
docker compose exec app mix phx.server

# In another terminal:

# List delivery options
curl http://localhost:4000/api/delivery_options

# Create an order
curl -X POST http://localhost:4000/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customer_name": "Hung Tran",
    "address": "123 Sample Street",
    "postcode": "2000",
    "total_cents": 9900,
    "status": "CREATED",
    "delivery_option_code": "EXPRESS"
  }'

# Get order with tracking
curl http://localhost:4000/api/orders/1

# Add a tracking event
curl -X POST http://localhost:4000/api/orders/1/tracking_events \
  -H "Content-Type: application/json" \
  -d '{
    "status": "IN_TRANSIT",
    "description": "Handed to carrier"
  }'
```

---

## 8. Checkpoint

You should now have:

- [x] Docker-based dev environment (app + Postgres)
- [x] 3 schemas with associations and changesets
- [x] Orders context with create + query logic
- [x] 4 JSON API endpoints
- [x] Seed data for delivery options
- [x] Working end-to-end flow via curl

**Next:** Guide 02 — Improving the App with OTP
