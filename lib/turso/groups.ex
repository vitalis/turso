defmodule Turso.Groups do
  @moduledoc """
  Group management for Turso Cloud Platform.

  Groups are logical containers for databases that share the same primary location
  and configuration. All databases within a group are replicated across the same
  set of locations.
  """

  use Turso.Schemas

  alias Turso.{Client, Error}

  @type group :: Turso.group()
  @type api_result(success_type) :: Turso.api_result(success_type)

  # Group listing options
  schema(:list_opts,
    organization: [
      type: :string,
      doc: "Organization slug. Overrides client default."
    ]
  )

  @doc """
  Lists all groups for the organization.

  ## Options

  #{doc(:list_opts)}

  ## Examples

      # List groups using client's default organization
      {:ok, groups} = Turso.Groups.list(client)

      # List groups for a specific organization
      {:ok, groups} = Turso.Groups.list(client, organization: "other-org")

  ## Returns

  - `{:ok, list(group())}` - List of group objects
  - `{:error, map()}` - Error details
  """
  @spec list(Turso.t(), keyword()) :: api_result(list(group()))
  def list(%Turso{} = client, opts \\ []) do
    opts = NimbleOptions.validate!(opts, @list_opts_schema)
    path = Client.org_path(client, ["groups"], opts[:organization])

    client
    |> Client.request(:get, path)
    |> Client.handle_response("groups")
  end

  # Group creation options
  schema(:create_opts,
    location: [
      type: :string,
      doc:
        "Primary location for the group (e.g., 'iad', 'lhr'). If not specified, uses the closest location."
    ],
    organization: [
      type: :string,
      doc: "Organization slug. Overrides client default."
    ]
  )

  @doc """
  Creates a new group in the organization.

  If no location is specified, the API will automatically select the closest
  available location.

  ## Options

  #{doc(:create_opts)}

  ## Examples

      # Basic group creation (auto-select location)
      {:ok, group} = Turso.Groups.create(client, "production")

      # Group with specific location
      {:ok, group} = Turso.Groups.create(client, "production", location: "iad")

  ## Returns

  - `{:ok, group()}` - Created group object
  - `{:error, map()}` - Error details
  """
  @spec create(Turso.t(), String.t(), keyword()) :: api_result(group())
  def create(%Turso{} = client, name, opts \\ []) do
    opts = NimbleOptions.validate!(opts, @create_opts_schema)

    with {:ok, location} <- resolve_location(client, opts[:location]) do
      path = Client.org_path(client, ["groups"], opts[:organization])

      body = %{
        "name" => name,
        "location" => location
      }

      client
      |> Client.request(:post, path, body)
      |> Client.handle_response()
    end
  end

  # Group retrieval options
  schema(:retrieve_opts,
    organization: [
      type: :string,
      doc: "Organization slug. Overrides client default."
    ]
  )

  @doc """
  Retrieves details of a specific group.

  ## Options

  #{doc(:retrieve_opts)}

  ## Examples

      {:ok, group} = Turso.Groups.retrieve(client, "production")

  ## Returns

  - `{:ok, group()}` - Group details
  - `{:error, map()}` - Error details
  """
  @spec retrieve(Turso.t(), String.t(), keyword()) :: api_result(group())
  def retrieve(%Turso{} = client, name, opts \\ []) do
    opts = NimbleOptions.validate!(opts, @retrieve_opts_schema)
    path = Client.org_path(client, ["groups", name], opts[:organization])

    client
    |> Client.request(:get, path)
    |> Client.handle_response()
  end

  # Group deletion options
  schema(:delete_opts,
    organization: [
      type: :string,
      doc: "Organization slug. Overrides client default."
    ]
  )

  @doc """
  Deletes a group.

  **Warning**: You cannot delete a group that contains databases. All databases
  in the group must be deleted first.

  ## Options

  #{doc(:delete_opts)}

  ## Examples

      {:ok, _} = Turso.Groups.delete(client, "old-group")

  ## Returns

  - `{:ok, map()}` - Deletion confirmation
  - `{:error, map()}` - Error details
  """
  @spec delete(Turso.t(), String.t(), keyword()) :: api_result(map())
  def delete(%Turso{} = client, name, opts \\ []) do
    opts = NimbleOptions.validate!(opts, @delete_opts_schema)
    path = Client.org_path(client, ["groups", name], opts[:organization])

    client
    |> Client.request(:delete, path)
    |> Client.handle_response()
  end

  # Group location addition options
  schema(:add_location_opts,
    organization: [
      type: :string,
      doc: "Organization slug. Overrides client default."
    ]
  )

  @doc """
  Adds a location to a group for database replication.

  This extends the group to replicate databases to an additional location,
  improving read performance for users in that region.

  ## Options

  #{doc(:add_location_opts)}

  ## Examples

      {:ok, group} = Turso.Groups.add_location(client, "production", "lhr")

  ## Returns

  - `{:ok, group()}` - Updated group object
  - `{:error, map()}` - Error details
  """
  @spec add_location(Turso.t(), String.t(), String.t(), keyword()) :: api_result(group())
  def add_location(%Turso{} = client, group_name, location, opts \\ []) do
    opts = NimbleOptions.validate!(opts, @add_location_opts_schema)

    path =
      Client.org_path(client, ["groups", group_name, "locations", location], opts[:organization])

    client
    |> Client.request(:post, path)
    |> Client.handle_response()
  end

  # Group location removal options
  schema(:remove_location_opts,
    organization: [
      type: :string,
      doc: "Organization slug. Overrides client default."
    ]
  )

  @doc """
  Removes a location from a group.

  **Warning**: You cannot remove the primary location of a group. At least one
  location must remain.

  ## Options

  #{doc(:remove_location_opts)}

  ## Examples

      {:ok, group} = Turso.Groups.remove_location(client, "production", "lhr")

  ## Returns

  - `{:ok, group()}` - Updated group object
  - `{:error, map()}` - Error details
  """
  @spec remove_location(Turso.t(), String.t(), String.t(), keyword()) :: api_result(group())
  def remove_location(%Turso{} = client, group_name, location, opts \\ []) do
    opts = NimbleOptions.validate!(opts, @remove_location_opts_schema)

    path =
      Client.org_path(client, ["groups", group_name, "locations", location], opts[:organization])

    client
    |> Client.request(:delete, path)
    |> Client.handle_response()
  end

  # Utility function for ensuring group exists
  schema(:ensure_exists_opts,
    location: [
      type: :string,
      doc: "Primary location for the group if it needs to be created."
    ],
    organization: [
      type: :string,
      doc: "Organization slug. Overrides client default."
    ]
  )

  @doc """
  Ensures a group exists, creating it if necessary.

  This is a utility function that checks if a group exists and creates it
  if it doesn't. This is useful when you want to ensure a group is available
  before performing other operations.

  ## Options

  #{doc(:ensure_exists_opts)}

  ## Examples

      # Ensure group exists (auto-select location if creation needed)
      {:ok, :exists} = Turso.Groups.ensure_exists(client, "production")

      # Ensure group exists with specific location
      {:ok, :created} = Turso.Groups.ensure_exists(client, "production", location: "iad")

  ## Returns

  - `{:ok, :exists}` - Group already existed
  - `{:ok, :created}` - Group was created
  - `{:error, map()}` - Error details
  """
  @spec ensure_exists(Turso.t(), String.t(), keyword()) ::
          {:ok, :exists | :created} | {:error, map()}
  def ensure_exists(%Turso{} = client, name, opts \\ []) do
    opts = NimbleOptions.validate!(opts, @ensure_exists_opts_schema)

    case retrieve(client, name, opts) do
      {:ok, _group} ->
        {:ok, :exists}

      {:error, %Error{type: :not_found}} ->
        case create(client, name, opts) do
          {:ok, _group} -> {:ok, :created}
          error -> error
        end

      error ->
        error
    end
  end

  # Private helper functions

  @spec resolve_location(Turso.t(), String.t() | nil) :: {:ok, String.t()} | {:error, map()}
  defp resolve_location(_client, location) when is_binary(location), do: {:ok, location}

  defp resolve_location(client, nil) do
    # Get the closest location from the locations API
    case Turso.Locations.closest(client) do
      {:ok, %{"client" => location}} -> {:ok, location}
      {:ok, %{"location" => location}} -> {:ok, location}
      {:ok, location} when is_binary(location) -> {:ok, location}
      # Fallback to IAD (US East)
      {:error, _} -> {:ok, "iad"}
      _ -> {:ok, "iad"}
    end
  end
end
