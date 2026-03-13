# Delivery App — AI Coding Agent Instructions

## Project overview
A delivery system built in Elixir/Phoenix to practice system design patterns.
This is a learning project, not a production app. Prioritize clarity and
explicitness over cleverness or brevity.

## Tech stack
- Elixir 1.19 + Erlang/OTP 28
- Phoenix 1.8.5 (API-only, JSON responses, no LiveView or HTML)
- Ecto + PostgreSQL 18
- ExUnit for testing
- Dockerfile + Docker Compose for local development environment

## Build & run commands
- Use `docker compose exec app <command>` to develop locally with Docker
- `mix deps.get` — install dependencies
- `mix compile` — compile the project
- `mix format` — format all files (run before every commit)
- `mix test` — run all tests
- `mix ecto.migrate` — run pending database migrations
- `mix ecto.rollback` — rollback the last migration
- `mix ecto.reset` — drop, create, migrate, and seed the database
- `mix phx.server` — start the dev server on localhost:4000
- `iex -S mix` — start an interactive Elixir shell with the app loaded

## Project structure
- `lib/delivery_app/orders/` — domain schemas (Order, DeliveryOption, TrackingEvent, Compensation)
- `lib/delivery_app/orders.ex` — Orders context, the public API for all order operations
- `lib/delivery_app/order_runtime/` — OTP layer (OrderProcess GenServer, DynamicSupervisor, Registry)
- `lib/delivery_app/orders/order_state.ex` — pure state machine for order status transitions
- `lib/delivery_app/event_bus.ex` — in-process event bus (GenServer)
- `lib/delivery_app/compensation/` — async compensation logic (Calculator, Handler)
- `lib/delivery_app/promise.ex` — delivery promise window calculation
- `lib/delivery_app/latency.ex` — late delivery detection
- `lib/delivery_app_web/controllers/` — JSON API controllers
- `lib/delivery_app_web/router.ex` — API routes under /api scope
- `guides/` — step-by-step learning guides (do not modify unless asked)
- `reflections/` — personal notes mapping patterns to real-world systems
- `diagrams/` — Mermaid architecture diagrams

## Code conventions

### General
- Use pattern matching for control flow, not if/else chains
- Use the pipe operator `|>` for data transformation chains
- Keep functions small and focused — one responsibility per function
- Prefer explicit over implicit: name things clearly, avoid abbreviations

### Architecture
- Context modules (`lib/delivery_app/*.ex`) are the public API
- Controllers should ONLY call context functions, never Repo directly
- Each domain concept gets its own schema module
- The OTP layer (OrderProcess, EventBus) sits behind the context — controllers don't know about GenServers
- Keep pure logic (OrderState, Calculator) separate from side-effectful code (Repo calls, process messages)

### Data
- All money values are in cents (integer, never float)
- Status values are uppercase strings: "CREATED", "PICKED_UP", "IN_TRANSIT", "DELIVERED", "CANCELLED"
- Timestamps use UTC (DateTime.utc_now())
- Database IDs are auto-incrementing integers (Ecto default)

### Testing
- Test pure modules (OrderState, Calculator, Promise) with unit tests
- Test context functions with database integration tests using Ecto sandbox
- Test controllers with Phoenix ConnTest
- Use descriptive test names: `test "cannot transition from DELIVERED to PICKED_UP"`

## When adding a new feature
1. Start with the migration + schema if new data is involved
2. Add context functions in the relevant context module
3. Write tests for the context functions
4. Add controller + route last
5. Run `mix format` and `mix test` before committing

## When modifying existing code
- Check if the function is used in tests — update tests to match
- If changing a context function signature, check which controllers call it
- If changing a schema, check if migrations need updating
- Run `mix test` after every change

## Commit message style
Use descriptive messages that explain what was learned, not just what changed:
- "Add DynamicSupervisor — learning process-per-entity pattern"
- "Implement OrderState transitions with pattern matching"
- "Add idempotency check to Compensation.Handler"

## Current phase
Guide 1 — Building the basic CRUD API

## Important notes
- This is a learning project. When suggesting code, include brief comments
  explaining WHY a pattern is used, not just what it does.
- Prefer showing Elixir-idiomatic solutions over porting patterns from other languages.
- When I ask about a concept, relate it back to Node/PHP/distributed systems
  where possible — that's the whole point of this project.
