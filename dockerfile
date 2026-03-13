FROM elixir:1.19.5-otp-28-alpine

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
