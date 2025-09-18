defmodule Turso.AuditLogs do
  @moduledoc """
  Audit log retrieval for Turso Cloud Platform.

  This module provides functions for accessing audit logs that track all
  activities and changes within your Turso organization. Audit logs are
  useful for compliance, security monitoring, and troubleshooting.
  """

  use Turso.Schemas

  alias Turso.Client

  @type audit_log :: %{String.t() => any()}
  @type api_result(success_type) :: Turso.api_result(success_type)

  # Audit log listing options
  schema(:list_opts,
    organization: [
      type: :string,
      doc: "Organization slug. Overrides client default."
    ],
    page_size: [
      type: :pos_integer,
      default: 100,
      doc: "Number of logs to return per page (max 1000)."
    ],
    page_token: [
      type: :string,
      doc: "Token for pagination to get the next page of results."
    ],
    order: [
      type: :string,
      doc: "Sort order: 'asc' for ascending, 'desc' for descending (default)."
    ],
    start_time: [
      type: :string,
      doc: "Start time for log filtering (ISO 8601 format)."
    ],
    end_time: [
      type: :string,
      doc: "End time for log filtering (ISO 8601 format)."
    ],
    action: [
      type: :string,
      doc: "Filter by specific action type (e.g., 'database.create')."
    ],
    actor_id: [
      type: :string,
      doc: "Filter by actor (user) ID who performed the action."
    ]
  )

  @doc """
  Lists audit logs for the organization.

  Returns a paginated list of audit log entries showing all activities
  within the organization.

  ## Options

  #{doc(:list_opts)}

  ## Examples

      # Basic audit log listing
      {:ok, response} = Turso.AuditLogs.list(client)

      # With pagination and filtering
      {:ok, response} = Turso.AuditLogs.list(client,
        page_size: 50,
        action: "database.create",
        start_time: "2024-01-01T00:00:00Z"
      )

  ## Returns

  - `{:ok, map()}` - Audit logs response with logs and pagination info
  - `{:error, map()}` - Error details

  ## Response Format

  The response typically contains:
  - `audit_logs` - Array of audit log entries
  - `page_token` - Token for next page (if more results available)
  - `has_more` - Boolean indicating if more results are available

  ## Audit Log Entry

  Each audit log entry contains:
  - `id` - Unique log entry ID
  - `timestamp` - When the action occurred (ISO 8601)
  - `action` - The action that was performed
  - `actor_id` - ID of the user who performed the action
  - `actor_email` - Email of the user who performed the action
  - `resource_type` - Type of resource affected (e.g., "database", "group")
  - `resource_id` - ID of the affected resource
  - `details` - Additional details about the action
  - `ip_address` - IP address of the actor
  - `user_agent` - User agent string of the request
  """
  @spec list(Turso.t(), keyword()) :: api_result(map())
  def list(%Turso{} = client, opts \\ []) do
    opts = NimbleOptions.validate!(opts, @list_opts_schema)
    path = Client.org_path(client, ["audit-logs"], opts[:organization])

    # Build query parameters
    params =
      opts
      |> Keyword.take([
        :page_size,
        :page_token,
        :order,
        :start_time,
        :end_time,
        :action,
        :actor_id
      ])
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Enum.into(%{})

    client
    |> Client.request(:get, path, nil, params: params)
    |> Client.handle_response()
  end

  @doc """
  Retrieves a specific audit log entry by ID.

  ## Examples

      {:ok, log_entry} = Turso.AuditLogs.retrieve(client, "log-123", organization: "my-org")

  ## Parameters

  - `client` - The Turso client
  - `log_id` - The audit log entry ID
  - `opts` - Options including organization override

  ## Returns

  - `{:ok, audit_log()}` - The audit log entry
  - `{:error, map()}` - Error details
  """
  @spec retrieve(Turso.t(), String.t(), keyword()) :: api_result(audit_log())
  def retrieve(%Turso{} = client, log_id, opts \\ []) do
    organization = Keyword.get(opts, :organization)
    path = Client.org_path(client, ["audit-logs", log_id], organization)

    client
    |> Client.request(:get, path)
    |> Client.handle_response()
  end

  @doc """
  Streams all audit logs for the organization.

  This is a convenience function that automatically handles pagination
  to retrieve all audit logs. It returns a stream that yields individual
  audit log entries.

  ## Examples

      # Stream all audit logs
      client
      |> Turso.AuditLogs.stream()
      |> Enum.take(100)

      # Stream with filtering
      client
      |> Turso.AuditLogs.stream(action: "database.create")
      |> Stream.filter(&filter_function/1)
      |> Enum.to_list()

  ## Parameters

  - `client` - The Turso client
  - `opts` - Same options as `list/2`, except page_token which is managed automatically

  ## Returns

  A `Stream` that yields individual audit log entries.

  ## Note

  This function makes multiple API calls as needed to fetch all pages.
  Use with care for large audit log datasets to avoid rate limiting.
  """
  @spec stream(Turso.t(), keyword()) :: Enumerable.t()
  def stream(%Turso{} = client, opts \\ []) do
    # Remove page_token from opts as we'll manage it internally
    base_opts = Keyword.delete(opts, :page_token)

    Stream.unfold(nil, &fetch_page(client, base_opts, &1))
    |> Stream.flat_map(& &1)
  end

  # Private helper function for pagination
  @spec fetch_page(Turso.t(), keyword(), any()) :: {list(), any()} | nil
  defp fetch_page(_client, _base_opts, :done), do: nil

  defp fetch_page(client, base_opts, page_token) do
    fetch_opts =
      case page_token do
        nil -> base_opts
        token -> Keyword.put(base_opts, :page_token, token)
      end

    case list(client, fetch_opts) do
      {:ok, %{"audit_logs" => logs, "page_token" => next_token}} when is_list(logs) ->
        next_state = if next_token, do: next_token, else: :done
        {logs, next_state}

      {:ok, %{"audit_logs" => logs}} when is_list(logs) ->
        {logs, :done}

      {:error, _reason} ->
        nil
    end
  end
end
