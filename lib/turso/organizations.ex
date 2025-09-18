defmodule Turso.Organizations do
  @moduledoc """
  Organization management for Turso Cloud Platform.

  Organizations are the top-level containers for all Turso resources including
  databases, groups, and members. This module provides functions for listing
  and retrieving organization information.
  """

  alias Turso.Client

  @type organization :: Turso.organization()
  @type api_result(success_type) :: Turso.api_result(success_type)

  @doc """
  Lists all organizations you have access to.

  This returns all organizations where you are a member, regardless of your
  role or permissions within each organization.

  ## Examples

      {:ok, organizations} = Turso.Organizations.list(client)

  ## Returns

  - `{:ok, list(organization())}` - List of organization objects
  - `{:error, map()}` - Error details

  ## Organization Object

  Each organization object typically contains:
  - `name` - Organization name
  - `slug` - URL-safe organization identifier
  - `type` - Organization type (e.g., "personal", "team")
  - `blocked` - Whether the organization is blocked
  """
  @spec list(Turso.t()) :: api_result(map())
  def list(%Turso{} = client) do
    client
    |> Client.request(:get, "/organizations")
    |> Client.handle_response("organizations")
  end

  @doc """
  Retrieves details of a specific organization.

  ## Examples

      {:ok, organization} = Turso.Organizations.retrieve(client, "my-org")

  ## Parameters

  - `client` - The Turso client
  - `organization_slug` - The organization's slug identifier

  ## Returns

  - `{:ok, organization()}` - Organization details
  - `{:error, map()}` - Error details
  """
  @spec retrieve(Turso.t(), String.t()) :: api_result(organization())
  def retrieve(%Turso{} = client, organization_slug) do
    path = "/organizations/#{organization_slug}"

    client
    |> Client.request(:get, path)
    |> Client.handle_response()
  end

  @doc """
  Gets usage statistics for an organization.

  Returns current usage metrics including database count, storage usage,
  bandwidth consumption, and other resource utilization data.

  ## Examples

      {:ok, usage} = Turso.Organizations.usage(client, "my-org")

  ## Parameters

  - `client` - The Turso client
  - `organization_slug` - The organization's slug identifier

  ## Returns

  - `{:ok, map()}` - Usage statistics
  - `{:error, map()}` - Error details

  ## Usage Object

  The usage object typically contains:
  - `databases` - Number of databases
  - `storage` - Storage usage in bytes
  - `bandwidth` - Bandwidth usage statistics
  - `requests` - API request counts
  """
  @spec usage(Turso.t(), String.t()) :: api_result(map())
  def usage(%Turso{} = client, organization_slug) do
    path = "/organizations/#{organization_slug}/usage"

    client
    |> Client.request(:get, path)
    |> Client.handle_response()
  end

  @doc """
  Gets organization limits and quotas.

  Returns information about the organization's resource limits, quotas,
  and current utilization against those limits.

  ## Examples

      {:ok, limits} = Turso.Organizations.limits(client, "my-org")

  ## Parameters

  - `client` - The Turso client
  - `organization_slug` - The organization's slug identifier

  ## Returns

  - `{:ok, map()}` - Limits and quotas information
  - `{:error, map()}` - Error details
  """
  @spec limits(Turso.t(), String.t()) :: api_result(map())
  def limits(%Turso{} = client, organization_slug) do
    path = "/organizations/#{organization_slug}/limits"

    client
    |> Client.request(:get, path)
    |> Client.handle_response()
  end

  @doc """
  Gets the organization's subscription information.

  Returns details about the organization's current subscription plan,
  billing information, and plan limits.

  ## Examples

      {:ok, subscription} = Turso.Organizations.subscription(client, "my-org")

  ## Parameters

  - `client` - The Turso client
  - `organization_slug` - The organization's slug identifier

  ## Returns

  - `{:ok, map()}` - Subscription details
  - `{:error, map()}` - Error details
  """
  @spec subscription(Turso.t(), String.t()) :: api_result(map())
  def subscription(%Turso{} = client, organization_slug) do
    path = "/organizations/#{organization_slug}/subscription"

    client
    |> Client.request(:get, path)
    |> Client.handle_response()
  end
end
