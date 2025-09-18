defmodule Turso.Databases do
  @moduledoc """
  Database operations for Turso Cloud Platform.

  This module provides functions for managing databases within Turso organizations,
  including creating, listing, retrieving, deleting databases, and managing
  database access tokens.
  """

  use Turso.Schemas

  alias Turso.Client

  @type database :: Turso.database()
  @type token :: Turso.token()
  @type api_result(success_type) :: Turso.api_result(success_type)

  # Database listing options
  schema(:list_opts,
    organization: [
      type: :string,
      doc: "Organization slug. Overrides client default."
    ]
  )

  @doc """
  Lists all databases for the organization.

  ## Options

  #{doc(:list_opts)}

  ## Examples

      # List databases using client's default organization
      {:ok, databases} = Turso.Databases.list(client)

      # List databases for a specific organization
      {:ok, databases} = Turso.Databases.list(client, organization: "other-org")

  ## Returns

  - `{:ok, list(database())}` - List of database objects
  - `{:error, map()}` - Error details
  """
  @spec list(Turso.t(), keyword()) :: api_result(list(database()))
  def list(%Turso{} = client, opts \\ []) do
    opts = NimbleOptions.validate!(opts, @list_opts_schema)
    path = Client.org_path(client, ["databases"], opts[:organization])

    client
    |> Client.request(:get, path)
    |> Client.handle_response("databases")
  end

  # Database creation options
  schema(:create_opts,
    group: [
      type: :string,
      default: "default",
      doc: "The group to create the database in."
    ],
    seed: [
      type: :map,
      doc: "Seed configuration for database initialization."
    ],
    size_limit: [
      type: :string,
      doc: "Maximum database size (e.g., '500mb', '1gb')."
    ],
    is_schema: [
      type: :boolean,
      default: false,
      doc: "Whether this database is a schema database."
    ],
    organization: [
      type: :string,
      doc: "Organization slug. Overrides client default."
    ]
  )

  @doc """
  Creates a new database in the specified group.

  Ensures the group exists before creating the database. If the group doesn't
  exist, it will be created automatically.

  ## Options

  #{doc(:create_opts)}

  ## Examples

      # Basic database creation
      {:ok, database} = Turso.Databases.create(client, "my-app-db")

      # Database with specific group and options
      {:ok, database} = Turso.Databases.create(client, "my-app-db",
        group: "production",
        size_limit: "500mb",
        is_schema: false
      )

  ## Returns

  - `{:ok, database()}` - Created database object
  - `{:error, map()}` - Error details
  """
  @spec create(Turso.t(), String.t(), keyword()) :: api_result(database())
  def create(%Turso{} = client, name, opts \\ []) do
    opts = NimbleOptions.validate!(opts, @create_opts_schema)

    # Ensure the group exists first
    group_name = opts[:group]

    group_opts = if opts[:organization], do: [organization: opts[:organization]], else: []

    with {:ok, _} <- Turso.Groups.ensure_exists(client, group_name, group_opts) do
      path = Client.org_path(client, ["databases"], opts[:organization])

      body =
        %{
          "name" => name,
          "group" => group_name
        }
        |> maybe_add_field("seed", opts[:seed])
        |> maybe_add_field("size_limit", opts[:size_limit])
        |> maybe_add_field("is_schema", opts[:is_schema])

      client
      |> Client.request(:post, path, body)
      |> Client.handle_response()
    end
  end

  # Database retrieval options
  schema(:retrieve_opts,
    organization: [
      type: :string,
      doc: "Organization slug. Overrides client default."
    ]
  )

  @doc """
  Retrieves details of a specific database.

  ## Options

  #{doc(:retrieve_opts)}

  ## Examples

      {:ok, database} = Turso.Databases.retrieve(client, "my-app-db")

      {:ok, database} = Turso.Databases.retrieve(client, "my-app-db",
        organization: "other-org"
      )

  ## Returns

  - `{:ok, database()}` - Database details
  - `{:error, map()}` - Error details
  """
  @spec retrieve(Turso.t(), String.t(), keyword()) :: api_result(database())
  def retrieve(%Turso{} = client, name, opts \\ []) do
    opts = NimbleOptions.validate!(opts, @retrieve_opts_schema)
    path = Client.org_path(client, ["databases", name], opts[:organization])

    client
    |> Client.request(:get, path)
    |> Client.handle_response()
  end

  # Database deletion options
  schema(:delete_opts,
    organization: [
      type: :string,
      doc: "Organization slug. Overrides client default."
    ]
  )

  @doc """
  Deletes a database.

  **Warning**: This operation is irreversible. All data in the database will be
  permanently lost.

  ## Options

  #{doc(:delete_opts)}

  ## Examples

      {:ok, _} = Turso.Databases.delete(client, "my-app-db")

  ## Returns

  - `{:ok, map()}` - Deletion confirmation
  - `{:error, map()}` - Error details
  """
  @spec delete(Turso.t(), String.t(), keyword()) :: api_result(map())
  def delete(%Turso{} = client, name, opts \\ []) do
    opts = NimbleOptions.validate!(opts, @delete_opts_schema)
    path = Client.org_path(client, ["databases", name], opts[:organization])

    client
    |> Client.request(:delete, path)
    |> Client.handle_response()
  end

  # Database token creation options
  schema(:create_token_opts,
    expiration: [
      type: :string,
      doc: "Token expiration (e.g., '1w', '30d', 'never')."
    ],
    authorization: [
      type: :string,
      doc: "Authorization level for the token."
    ],
    organization: [
      type: :string,
      doc: "Organization slug. Overrides client default."
    ]
  )

  @doc """
  Creates a database token for libSQL connections.

  Database tokens are used to authenticate connections to individual databases
  using libSQL clients.

  ## Options

  #{doc(:create_token_opts)}

  ## Examples

      # Basic token creation
      {:ok, token} = Turso.Databases.create_token(client, "my-app-db")

      # Token with expiration and authorization
      {:ok, token} = Turso.Databases.create_token(client, "my-app-db",
        expiration: "1w",
        authorization: "read-only"
      )

  ## Returns

  - `{:ok, token()}` - Token details including the JWT
  - `{:error, map()}` - Error details
  """
  @spec create_token(Turso.t(), String.t(), keyword()) :: api_result(token())
  def create_token(%Turso{} = client, database_name, opts \\ []) do
    opts = NimbleOptions.validate!(opts, @create_token_opts_schema)

    path =
      Client.org_path(client, ["databases", database_name, "auth", "tokens"], opts[:organization])

    body =
      %{}
      |> maybe_add_field("expiration", opts[:expiration])
      |> maybe_add_field("authorization", opts[:authorization])

    client
    |> Client.request(:post, path, body)
    |> Client.handle_response()
  end

  # Database token invalidation options
  schema(:invalidate_tokens_opts,
    organization: [
      type: :string,
      doc: "Organization slug. Overrides client default."
    ]
  )

  @doc """
  Invalidates all database tokens for a database.

  This will immediately revoke all existing tokens for the database, requiring
  new tokens to be created for future connections.

  ## Options

  #{doc(:invalidate_tokens_opts)}

  ## Examples

      {:ok, _} = Turso.Databases.invalidate_tokens(client, "my-app-db")

  ## Returns

  - `{:ok, map()}` - Invalidation confirmation
  - `{:error, map()}` - Error details
  """
  @spec invalidate_tokens(Turso.t(), String.t(), keyword()) :: api_result(map())
  def invalidate_tokens(%Turso{} = client, database_name, opts \\ []) do
    opts = NimbleOptions.validate!(opts, @invalidate_tokens_opts_schema)

    path =
      Client.org_path(client, ["databases", database_name, "auth", "tokens"], opts[:organization])

    client
    |> Client.request(:delete, path)
    |> Client.handle_response()
  end

  # Database configuration options
  schema(:update_opts,
    allow_attach: [
      type: :boolean,
      doc: "Whether to allow ATTACH statements."
    ],
    size_limit: [
      type: :string,
      doc: "Maximum database size (e.g., '500mb', '1gb')."
    ],
    organization: [
      type: :string,
      doc: "Organization slug. Overrides client default."
    ]
  )

  @doc """
  Updates database configuration.

  ## Options

  #{doc(:update_opts)}

  ## Examples

      {:ok, database} = Turso.Databases.update(client, "my-app-db",
        allow_attach: false,
        size_limit: "1gb"
      )

  ## Returns

  - `{:ok, database()}` - Updated database object
  - `{:error, map()}` - Error details
  """
  @spec update(Turso.t(), String.t(), keyword()) :: api_result(database())
  def update(%Turso{} = client, name, opts \\ []) do
    opts = NimbleOptions.validate!(opts, @update_opts_schema)
    path = Client.org_path(client, ["databases", name, "configuration"], opts[:organization])

    body =
      %{}
      |> maybe_add_field("allow_attach", opts[:allow_attach])
      |> maybe_add_field("size_limit", opts[:size_limit])

    client
    |> Client.request(:patch, path, body)
    |> Client.handle_response()
  end

  # Private helper functions

  @spec maybe_add_field(map(), String.t(), any()) :: map()
  defp maybe_add_field(map, _key, nil), do: map
  defp maybe_add_field(map, key, value), do: Map.put(map, key, value)
end
