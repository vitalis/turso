defmodule Turso.Mock do
  @moduledoc """
  Mock HTTP server for testing Turso API client.

  This module provides a Plug-based mock server that simulates the Turso API
  for testing purposes. It follows the pattern from Anthropix for realistic
  HTTP testing without external dependencies.

  ## Usage

      # Create a mock client
      client = Turso.Mock.client(& Turso.Mock.respond(&1, :database_list))

      # Use the client normally
      {:ok, databases} = Turso.list_databases(client)

  ## Mock Data

  The mock responses are designed to match the actual Turso API structure,
  making tests realistic and catching integration issues early.
  """

  import Plug.Conn
  alias Plug.Conn.Status

  # Mock response data matching Turso API structure
  @mock_responses %{
    # Database responses
    database_list: %{
      "databases" => [
        %{
          "Name" => "test-db-1",
          "DbId" => "db-id-123",
          "Hostname" => "test-db-1-org.turso.io",
          "Group" => "default",
          "Version" => "0.24.4",
          "PrimaryRegion" => "iad",
          "Regions" => ["iad"],
          "Type" => "regular",
          "IsSchema" => false,
          "Schema" => nil,
          "CreatedAt" => "2024-01-15T10:30:00Z",
          "UpdatedAt" => "2024-01-15T10:30:00Z"
        },
        %{
          "Name" => "test-db-2",
          "DbId" => "db-id-456",
          "Hostname" => "test-db-2-org.turso.io",
          "Group" => "production",
          "Version" => "0.24.4",
          "PrimaryRegion" => "lhr",
          "Regions" => ["lhr", "iad"],
          "Type" => "regular",
          "IsSchema" => false,
          "Schema" => nil,
          "CreatedAt" => "2024-01-10T08:15:00Z",
          "UpdatedAt" => "2024-01-10T08:15:00Z"
        }
      ]
    },
    database_create: %{
      "database" => %{
        "Name" => "new-test-db",
        "DbId" => "db-id-789",
        "Hostname" => "new-test-db-org.turso.io",
        "Group" => "default",
        "Version" => "0.24.4",
        "PrimaryRegion" => "iad",
        "Regions" => ["iad"],
        "Type" => "regular",
        "IsSchema" => false,
        "Schema" => nil,
        "CreatedAt" => "2024-01-16T12:00:00Z",
        "UpdatedAt" => "2024-01-16T12:00:00Z"
      }
    },
    database_token: %{
      "jwt" => "eyJ0eXAiOiJKV1QiLCJhbGciOiJFZERTQSJ9.example_token_payload.signature"
    },

    # Group responses
    group_list: %{
      "groups" => [
        %{
          "name" => "default",
          "primary_region" => "iad",
          "regions" => ["iad"],
          "archived" => false,
          "uuid" => "group-uuid-123"
        },
        %{
          "name" => "production",
          "primary_region" => "lhr",
          "regions" => ["lhr", "iad"],
          "archived" => false,
          "uuid" => "group-uuid-456"
        }
      ]
    },
    group_create: %{
      "group" => %{
        "name" => "new-group",
        "primary_region" => "iad",
        "regions" => ["iad"],
        "archived" => false,
        "uuid" => "group-uuid-789"
      }
    },

    # Organization responses
    organization_list: %{
      "organizations" => [
        %{
          "name" => "Test Organization",
          "slug" => "test-org",
          "type" => "personal",
          "blocked" => false
        }
      ]
    },
    organization_detail: %{
      "organization" => %{
        "name" => "Test Organization",
        "slug" => "test-org",
        "type" => "personal",
        "blocked" => false
      }
    },

    # Location responses
    location_list: %{
      "locations" => [
        %{
          "code" => "iad",
          "name" => "Washington, D.C. (IAD)"
        },
        %{
          "code" => "lhr",
          "name" => "London (LHR)"
        },
        %{
          "code" => "nrt",
          "name" => "Tokyo (NRT)"
        }
      ]
    },
    closest_region: %{"client" => "iad", "server" => "aws-us-east-1"},

    # Token responses
    token_list: %{
      "tokens" => [
        %{
          "name" => "test-token",
          "id" => "token-id-123",
          "created_at" => "2024-01-01T00:00:00Z"
        }
      ]
    },
    token_create: %{
      "token" => %{
        "name" => "new-token",
        "id" => "token-id-456",
        "token" => "test_api_token_value_here",
        "created_at" => "2024-01-16T12:00:00Z"
      }
    },
    token_validate: %{
      "exp" => 1_735_689_600,
      "id" => "token-id-123"
    },

    # Audit log responses
    audit_logs: %{
      "audit_logs" => [
        %{
          "id" => "log-123",
          "timestamp" => "2024-01-16T12:00:00Z",
          "action" => "database.create",
          "actor_id" => "user-123",
          "actor_email" => "test@example.com",
          "resource_type" => "database",
          "resource_id" => "test-db",
          "details" => %{"group" => "default"},
          "ip_address" => "192.168.1.1",
          "user_agent" => "Turso CLI"
        }
      ],
      "page_token" => nil,
      "has_more" => false
    }
  }

  @doc """
  Creates a mock Turso client that uses the provided Plug function.

  ## Parameters

  - `plug` - A function that handles HTTP requests (usually `& Turso.Mock.respond(&1, response_type)`)

  ## Returns

  A `Turso.t()` struct configured to use the mock server.

  ## Examples

      # Simple response
      client = Turso.Mock.client(& Turso.Mock.respond(&1, :database_list))

      # Custom response handler
      client = Turso.Mock.client(fn conn ->
        if String.contains?(conn.request_path, "databases") do
          Turso.Mock.respond(conn, :database_list)
        else
          Turso.Mock.respond(conn, 404)
        end
      end)
  """
  @spec client(function()) :: Turso.t()
  def client(plug) when is_function(plug, 1) do
    %Turso{
      api_token: "mock_token",
      organization: "test-org",
      base_url: "https://api.turso.tech/v1",
      req: Req.new(plug: plug, retry: false)
    }
  end

  @doc """
  Responds with a mock response for the given response type.

  ## Parameters

  - `conn` - The Plug connection
  - `response_type` - Atom identifying the mock response or HTTP status code

  ## Examples

      Turso.Mock.respond(conn, :database_list)
      Turso.Mock.respond(conn, :database_create)
      Turso.Mock.respond(conn, 404)  # Not found error
      Turso.Mock.respond(conn, 401)  # Unauthorized error
  """
  @spec respond(Plug.Conn.t(), atom() | integer() | map()) :: Plug.Conn.t()
  def respond(conn, response_type)

  # Handle custom map responses
  def respond(conn, response_data) when is_map(response_data) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, Jason.encode!(response_data))
  end

  # Handle mock responses by atom
  def respond(conn, response_type) when is_atom(response_type) do
    case Map.get(@mock_responses, response_type) do
      nil ->
        respond_error(conn, 404, "Mock response '#{response_type}' not found")

      response_data ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(200, Jason.encode!(response_data))
    end
  end

  # Handle HTTP status code responses
  def respond(conn, status) when is_integer(status) and status >= 400 do
    respond_error(conn, status, Status.reason_phrase(status))
  end

  def respond(conn, status) when is_integer(status) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(status, Jason.encode!(%{}))
  end

  @doc """
  Responds with a custom error message and status code.

  ## Examples

      Turso.Mock.respond_error(conn, 409, "Database already exists")
  """
  @spec respond_error(Plug.Conn.t(), integer(), String.t()) :: Plug.Conn.t()
  def respond_error(conn, status, message) do
    error_response = %{
      "error" => %{
        "code" => Status.reason_atom(status),
        "message" => message
      }
    }

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(status, Jason.encode!(error_response))
  end

  @doc """
  Responds with a rate limiting error including retry-after header.

  ## Examples

      Turso.Mock.respond_rate_limited(conn, 60)  # Retry after 60 seconds
  """
  @spec respond_rate_limited(Plug.Conn.t(), integer()) :: Plug.Conn.t()
  def respond_rate_limited(conn, retry_after_seconds \\ 60) do
    error_response = %{
      "error" => %{
        "code" => "rate_limit_exceeded",
        "message" => "Rate limit exceeded. Try again later.",
        "retry_after" => retry_after_seconds
      }
    }

    conn
    |> put_resp_header("content-type", "application/json")
    |> put_resp_header("retry-after", Integer.to_string(retry_after_seconds))
    |> send_resp(429, Jason.encode!(error_response))
  end

  @doc """
  Creates a request-aware mock that responds differently based on the request.

  This is useful for testing scenarios where different endpoints or request
  methods should return different responses.

  ## Examples

      client = Turso.Mock.client(Turso.Mock.request_router(%{
        "GET /v1/organizations/test-org/databases" => :database_list,
        "POST /v1/organizations/test-org/databases" => :database_create,
        "GET /v1/locations" => :location_list
      }))
  """
  @spec request_router(map()) :: function()
  def request_router(route_map) do
    fn conn ->
      route_key = "#{conn.method} #{conn.request_path}"

      case Map.get(route_map, route_key) do
        nil ->
          respond_error(conn, 404, "Route not found: #{route_key}")

        response_type ->
          respond(conn, response_type)
      end
    end
  end

  @doc """
  Inspects the request and returns details for debugging.

  ## Examples

      client = Turso.Mock.client(& Turso.Mock.inspect_request(&1))
      Turso.list_databases(client)  # Will log request details
  """
  @spec inspect_request(Plug.Conn.t()) :: Plug.Conn.t()
  def inspect_request(conn) do
    IO.inspect(
      %{
        method: conn.method,
        path: conn.request_path,
        query: conn.query_string,
        headers: conn.req_headers,
        body: conn.body_params
      },
      label: "Mock Request"
    )

    respond(conn, 200)
  end

  @doc """
  Returns the available mock response types.

  Useful for discovering what mock responses are available for testing.

  ## Examples

      Turso.Mock.available_responses()
      # => [:database_list, :database_create, :group_list, ...]
  """
  @spec available_responses() :: list(atom())
  def available_responses do
    Map.keys(@mock_responses)
  end

  @doc """
  Gets the mock response data for a given type.

  Useful for assertions in tests to verify against expected data.

  ## Examples

      expected = Turso.Mock.get_mock_data(:database_list)
      assert result == expected["databases"]
  """
  @spec get_mock_data(atom()) :: map() | nil
  def get_mock_data(response_type) do
    Map.get(@mock_responses, response_type)
  end
end
