# Elixir client for Turso Cloud Platform API

![Turso](https://turso.tech/logokit/turso-logo-illustrated.png)

[![hex.pm version](https://img.shields.io/hexpm/v/turso.svg)](https://hex.pm/packages/turso)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/turso/)
[![hex.pm license](https://img.shields.io/hexpm/l/turso.svg)](https://github.com/vitalis/turso/blob/main/LICENSE)
[![Build Status](https://github.com/vitalis/turso/workflows/CI/badge.svg)](https://github.com/vitalis/turso/actions)
[![Coverage Status](https://coveralls.io/repos/github/vitalis/turso/badge.svg?branch=main)](https://coveralls.io/github/vitalis/turso?branch=main)
[![Last Updated](https://img.shields.io/github/last-commit/vitalis/turso.svg)](https://github.com/vitalis/turso/commits/main)

---

Elixir client for [Turso Cloud Platform API](https://turso.tech), providing access to distributed SQLite databases.

- ✅ Complete [Turso Cloud Platform API](https://docs.turso.tech/api-reference) implementation
- 🌍 Multi-region database support with edge replication
- ⚡ Configurable HTTP client with retry strategies
- 🛡️ Comprehensive error handling with helper functions
- 🧪 Built-in mock server for testing
- 📊 Streaming support for large datasets
- 🔧 Full type specifications with Dialyzer support

## Installation

The package can be installed by adding `turso` to your list of dependencies in `mix.exs`.

```elixir
def deps do
  [
    {:turso, "~> 0.1.0"}
  ]
end
```

## Quickstart

### Configuration

By default, HTTP retries are disabled for better control. You can configure the underlying HTTP client behavior:

```elixir
# config/config.exs
config :turso, :req_options,
  retry: :safe_transient,  # Enable retries for safe operations
  max_retries: 3,
  receive_timeout: 60_000
```

For more examples, refer to the [Turso documentation](https://hexdocs.pm/turso).

### Initialize a client

See `Turso.init/2`.

```elixir
client = Turso.init("your-api-token")
```

### Manage databases

See `Turso.Databases`.

```elixir
# List databases
{:ok, databases} = Turso.list_databases(client)

# Create a database
{:ok, database} = Turso.create_database(client, "my-app-db", [
  group: "production",
  size_limit: "1gb"
])

# Create database connection token
{:ok, token} = Turso.create_database_token(client, "my-app-db", [
  expiration: "30d",
  authorization: "full-access"
])
```

### Working with groups

See `Turso.Groups`.

```elixir
# Create a group in multiple regions
{:ok, group} = Turso.create_group(client, "global", location: "iad")
{:ok, group} = Turso.add_location(client, "global", "lhr")
{:ok, group} = Turso.add_location(client, "global", "nrt")

# Ensure group exists (create if needed)
{:ok, :exists} = Turso.ensure_group_exists(client, "staging")
```

### Error handling

The library provides comprehensive error handling with helper functions:

```elixir
case Turso.create_database(client, "existing-db") do
  {:ok, database} ->
    IO.puts("Database created!")

  {:error, %Turso.Error{} = error} ->
    cond do
      Turso.Error.rate_limited?(error) ->
        retry_after = Turso.Error.retry_after(error)
        IO.puts("Rate limited, retry after #{retry_after}s")

      Turso.Error.auth_error?(error) ->
        IO.puts("Authentication failed")

      Turso.Error.retryable?(error) ->
        IO.puts("Retryable error occurred")

      true ->
        IO.puts("Error: #{error.message}")
    end
end
```

### Streaming

Stream large datasets efficiently:

```elixir
# Stream all audit logs with automatic pagination
client
|> Turso.stream_audit_logs(action: "database.delete")
|> Stream.filter(&recent?/1)
|> Enum.take(100)
```

### Testing

Use the built-in mock server for testing:

```elixir
test "database operations" do
  client = Turso.Mock.client(&Turso.Mock.respond(&1, :database_list))

  assert {:ok, databases} = Turso.list_databases(client)
  assert is_list(databases)
end
```

## License

This project is licensed under the Apache 2.0 License - see the [LICENSE](LICENSE) file for details.

## Links

- [Turso Platform](https://turso.tech)
- [API Documentation](https://docs.turso.tech/api-reference)
- [Full Documentation](https://hexdocs.pm/turso)
