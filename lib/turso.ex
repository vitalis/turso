defmodule Turso do
  @moduledoc """
  Elixir client library for Turso Cloud Platform API.

  Turso provides a distributed SQLite database platform. This library implements
  a complete client for the Turso Platform API, allowing you to manage databases,
  groups, organizations, and more.

  ## Usage

      # Initialize a client
      client = Turso.init(api_token, organization: "my-org")

      # Create a database
      {:ok, database} = Turso.create_database(client, "my-app-db", group: "production")

      # List databases
      {:ok, databases} = Turso.list_databases(client)

  See the individual modules for detailed documentation:
  - `Turso.Databases` - Database management
  - `Turso.Groups` - Group management
  - `Turso.Organizations` - Organization information
  - `Turso.Locations` - Location discovery
  - `Turso.Tokens` - API token management
  - `Turso.AuditLogs` - Audit log access
  """

  use Turso.Schemas

  alias Turso.Error

  @type t :: %__MODULE__{
          api_token: String.t(),
          organization: String.t() | nil,
          base_url: String.t(),
          req: Req.Request.t()
        }

  @type database :: map()
  @type group :: map()
  @type organization :: map()
  @type location :: map()
  @type token :: map()
  @type api_result(success_type) :: {:ok, success_type} | {:error, Error.t()}

  defstruct [:api_token, :organization, :base_url, :req]

  # Client initialization options
  schema(:init_opts,
    organization: [
      type: :string,
      doc: "Default organization slug for API calls. Can be overridden per function."
    ],
    base_url: [
      type: :string,
      default: "https://api.turso.tech/v1",
      doc: "Base URL for Turso API requests."
    ],
    receive_timeout: [
      type: :timeout,
      default: 30_000,
      doc: "HTTP receive timeout in milliseconds."
    ]
  )

  @doc """
  Initialize a new Turso client.

  Creates a client struct with the provided API token and options. The client
  contains a pre-configured Req HTTP client for making API requests.

  ## Options

  #{doc(:init_opts)}

  ## Examples

      client = Turso.init("your-api-token")
      client = Turso.init("your-api-token", organization: "my-org")

  ## Returns

  A `Turso.t()` client struct ready for API operations.
  """
  @spec init(String.t(), keyword()) :: t()
  def init(api_token, opts \\ []) when is_binary(api_token) do
    opts = NimbleOptions.validate!(opts, @init_opts_schema)

    # Get req_options from application config, disable retries by default
    req_options = Application.get_env(:turso, :req_options, [])
    default_req_options = [retry: false]

    req_options = Keyword.merge(default_req_options, req_options)

    req =
      Req.new(
        [
          base_url: opts[:base_url],
          headers: [
            {"authorization", "Bearer #{api_token}"},
            {"content-type", "application/json"}
          ],
          receive_timeout: opts[:receive_timeout]
        ] ++ req_options
      )

    %__MODULE__{
      api_token: api_token,
      organization: opts[:organization],
      base_url: opts[:base_url],
      req: req
    }
  end

  # ============================================================================
  # Database Management
  # ============================================================================

  @doc "Lists all databases for the organization. See `Turso.Databases.list/2`."
  @spec list_databases(t()) :: api_result(map())
  def list_databases(%__MODULE__{} = client) do
    Turso.Databases.list(client)
  end

  @doc "Creates a new database. See `Turso.Databases.create/3`."
  @spec create_database(t(), String.t(), keyword()) :: api_result(map())
  def create_database(%__MODULE__{} = client, name, opts \\ []) do
    Turso.Databases.create(client, name, opts)
  end

  @doc "Retrieves a specific database. See `Turso.Databases.retrieve/2`."
  @spec retrieve_database(t(), String.t()) :: api_result(map())
  def retrieve_database(%__MODULE__{} = client, name) do
    Turso.Databases.retrieve(client, name)
  end

  @doc "Deletes a database. See `Turso.Databases.delete/2`."
  @spec delete_database(t(), String.t()) :: api_result(map())
  def delete_database(%__MODULE__{} = client, name) do
    Turso.Databases.delete(client, name)
  end

  @doc "Creates a database token. See `Turso.Databases.create_token/3`."
  @spec create_database_token(t(), String.t(), keyword()) :: api_result(map())
  def create_database_token(%__MODULE__{} = client, database_name, opts \\ []) do
    Turso.Databases.create_token(client, database_name, opts)
  end

  # ============================================================================
  # Group Management
  # ============================================================================

  @doc "Lists all groups. See `Turso.Groups.list/2`."
  @spec list_groups(t()) :: api_result(map())
  def list_groups(%__MODULE__{} = client) do
    Turso.Groups.list(client)
  end

  @doc "Creates a new group. See `Turso.Groups.create/3`."
  @spec create_group(t(), String.t(), keyword()) :: api_result(map())
  def create_group(%__MODULE__{} = client, name, opts \\ []) do
    Turso.Groups.create(client, name, opts)
  end

  # ============================================================================
  # Organization Management
  # ============================================================================

  @doc "Lists all organizations. See `Turso.Organizations.list/1`."
  @spec list_organizations(t()) :: api_result(map())
  def list_organizations(%__MODULE__{} = client) do
    Turso.Organizations.list(client)
  end

  # ============================================================================
  # Location Discovery
  # ============================================================================

  @doc "Lists all available locations. See `Turso.Locations.list/1`."
  @spec list_locations(t()) :: api_result(list(map()))
  def list_locations(%__MODULE__{} = client) do
    Turso.Locations.list(client)
  end
end
