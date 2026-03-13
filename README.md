# Delivery App — System Design Through Elixir

A delivery system built in Elixir/Phoenix to practice system design patterns — state machines, OTP supervision, event-driven architecture, idempotency, and failure handling — using a domain I work with professionally.

This is not a production app. It's an **architecture lab**: a place to prototype patterns, break things on purpose, and build muscle memory for designing systems that handle reality.

## Why Elixir?

Elixir/OTP forces you to think explicitly about things most languages let you ignore: process isolation, supervision trees, message passing, crash recovery. Learning these patterns here makes you better at designing Node/PHP/Go systems — even if you never ship Elixir to production.

## What I'm practicing

| Pattern | Where in the app | Real-world equivalent |
|---------|-----------------|----------------------|
| **Finite state machines** | `OrderState.allowed_transition?/2` | Order lifecycle in any e-commerce system |
| **Process-per-entity** | `OrderProcess` GenServer per order | Actor model, worker pools, saga orchestrators |
| **Supervision & crash recovery** | `DynamicSupervisor` + `Registry` | Circuit breakers, retry strategies, health checks |
| **Delivery promises** | `Promise.calculate/3` | SLA calculations, ETA windows |
| **Late delivery detection** | `Latency.late?/2` | SLA breach monitoring |
| **Event-driven compensation** | `EventBus` + `Compensation.Handler` | Kafka/RabbitMQ consumers, async side-effects |
| **Idempotent event handling** | `processed_events` table | Exactly-once processing, deduplication |

## Project structure

```
delivery_app/
├── lib/
│   ├── delivery_app/
│   │   ├── orders/                  # Domain schemas
│   │   │   ├── order.ex
│   │   │   ├── delivery_option.ex
│   │   │   ├── tracking_event.ex
│   │   │   ├── order_state.ex       # Pure state machine
│   │   │   └── compensation.ex
│   │   ├── orders.ex                # Orders context (public API)
│   │   ├── order_runtime/           # OTP layer
│   │   │   └── order_process.ex     # GenServer per order
│   │   ├── promise.ex               # Delivery promise calculation
│   │   ├── latency.ex               # Late delivery detection
│   │   ├── event_bus.ex             # In-process event bus
│   │   └── compensation/
│   │       ├── calculator.ex        # Compensation amount logic
│   │       └── handler.ex           # Async event handler
│   └── delivery_app_web/
│       ├── controllers/             # JSON API controllers
│       └── router.ex
├── guides/                          # Step-by-step learning guides
│   ├── 01-phoenix-api.md
│   ├── 02-otp-processes.md
│   ├── 03-workflow-design.md
│   ├── 04-events-compensation.md
│   └── 05-idempotency-failures.md
├── reflections/                     # Notes mapping patterns to Node/PHP
│   ├── week-2-crud-to-work.md
│   ├── week-4-otp-patterns.md
│   ├── week-6-rfc-late-delivery.md
│   └── week-8-final-review.md
├── diagrams/                        # Architecture diagrams
│   ├── state-machine.mermaid
│   ├── event-flow.mermaid
│   └── compensation-sequence.mermaid
├── test/
├── priv/repo/migrations/
└── mix.exs
```

## Learning path

The project is built in 5 progressive guides, each adding architectural depth:

### Guide 1 — Tiny Phoenix Delivery API
Basic CRUD: schemas, migrations, context module, JSON controllers. Get a working API you can hit with curl.

### Guide 2 — Improving the App with OTP
Add a `DynamicSupervisor`, `Registry`, and per-order `GenServer`. Validate state transitions in memory. Simulate crashes and watch recovery.

### Guide 3 — End-to-End Workflow Design
Add delivery promise windows and late delivery detection. Domain modeling with real business rules.

### Guide 4 — Events + Async Compensation
Build an in-process `EventBus`. Emit `ShipmentDelivered` events. Create compensation records asynchronously when deliveries are late.

### Guide 5 — Idempotency, Failures & Consistency
Make event handlers idempotent with a `processed_events` table. Simulate partial failures. Test crash-and-recovery flows.

## Tech stack

- Elixir 1.17 + Erlang/OTP 27
- Phoenix 1.7 (API-only, no LiveView)
- Ecto + PostgreSQL 16
- ExUnit for testing

## Running locally

```bash
# Install dependencies
mix deps.get

# Create and migrate the database
mix ecto.setup

# Seed delivery options
mix run priv/repo/seeds.exs

# Start the server
mix phx.server
```

API is available at `http://localhost:4000/api`.

## API endpoints

```
GET    /api/delivery_options              # List active delivery options
POST   /api/orders                        # Create an order
GET    /api/orders/:id                    # Get order with tracking history
POST   /api/orders/:id/tracking_events    # Append a tracking event
POST   /api/orders/:id/transitions        # Transition order status (OTP)
GET    /api/orders/:id/overview           # Full view with compensation
```

## Reflections

Each phase includes a reflection note mapping what I learned to real-world Node/PHP systems. These live in `reflections/` and are the most valuable part of this project — they're where toy-project learning turns into professional design thinking.

## Status

> **Current phase:** Guide 1 — Building the basic CRUD API
