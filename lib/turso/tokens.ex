defmodule Turso.Tokens do
  @moduledoc """
  API token management for Turso Cloud Platform.

  This module provides functions for managing API tokens that are used to
  authenticate with the Turso Platform API. These are different from database
  tokens, which are used for libSQL connections.
  """

  use Turso.Schemas

  alias Turso.Client

  @type token :: Turso.token()
  @type api_result(success_type) :: Turso.api_result(success_type)

  @doc """
  Lists all API tokens for the authenticated user.

  ## Examples

      {:ok, tokens} = Turso.Tokens.list(client)

  ## Returns

  - `{:ok, list(token())}` - List of API token objects
  - `{:error, map()}` - Error details

  ## Token Object

  Each token object typically contains:
  - `name` - Token name/identifier
  - `id` - Unique token ID
  - `created_at` - Creation timestamp
  - `last_used_at` - Last usage timestamp (if available)
  """
  @spec list(Turso.t()) :: api_result(map())
  def list(%Turso{} = client) do
    client
    |> Client.request(:get, "/auth/api-tokens")
    |> Client.handle_response("tokens")
  end

  # API token creation options
  schema(:create_opts,
    description: [
      type: :string,
      doc: "Optional description for the token."
    ]
  )

  @doc """
  Creates a new API token.

  **Important**: The token value is only returned once during creation.
  Make sure to store it securely as it cannot be retrieved again.

  ## Options

  #{doc(:create_opts)}

  ## Examples

      # Basic token creation
      {:ok, token} = Turso.Tokens.create(client, "my-app-token")

      # Token with description
      {:ok, token} = Turso.Tokens.create(client, "my-app-token",
        description: "Token for production deployment"
      )

  ## Parameters

  - `client` - The Turso client
  - `name` - A unique name for the token

  ## Returns

  - `{:ok, token()}` - Created token object with the token value
  - `{:error, map()}` - Error details

  ## Security Note

  The returned token object will contain the actual token value in a field
  like `token` or `value`. This is the only time you'll be able to access
  the token value, so store it securely immediately.
  """
  @spec create(Turso.t(), String.t(), keyword()) :: api_result(token())
  def create(%Turso{} = client, name, opts \\ []) do
    opts = NimbleOptions.validate!(opts, @create_opts_schema)
    path = "/auth/api-tokens/#{name}"

    body =
      %{}
      |> maybe_add_field("description", opts[:description])

    client
    |> Client.request(:post, path, body)
    |> Client.handle_response()
  end

  @doc """
  Validates the current API token.

  This endpoint can be used to check if the current token is valid and
  retrieve information about it.

  ## Examples

      {:ok, token_info} = Turso.Tokens.validate(client)

  ## Returns

  - `{:ok, map()}` - Token validation information
  - `{:error, map()}` - Error details (likely invalid token)

  ## Validation Response

  The validation response typically contains:
  - `valid` - Whether the token is valid
  - `token_name` - Name of the token
  - `expires_at` - Token expiration (if applicable)
  """
  @spec validate(Turso.t()) :: api_result(map())
  def validate(%Turso{} = client) do
    client
    |> Client.request(:get, "/auth/validate")
    |> Client.handle_response()
  end

  @doc """
  Revokes (deletes) an API token.

  **Warning**: This action is irreversible. The token will be immediately
  invalidated and cannot be recovered.

  ## Examples

      {:ok, _} = Turso.Tokens.revoke(client, "my-app-token")

  ## Parameters

  - `client` - The Turso client
  - `name` - The name of the token to revoke

  ## Returns

  - `{:ok, map()}` - Revocation confirmation
  - `{:error, map()}` - Error details

  ## Security Note

  You cannot revoke the token that is currently being used to authenticate
  the request. Use a different token or the Turso CLI to revoke the current token.
  """
  @spec revoke(Turso.t(), String.t()) :: api_result(map())
  def revoke(%Turso{} = client, name) do
    path = "/auth/api-tokens/#{name}"

    client
    |> Client.request(:delete, path)
    |> Client.handle_response()
  end

  @doc """
  Retrieves information about a specific API token.

  ## Examples

      {:ok, token} = Turso.Tokens.retrieve(client, "my-app-token")

  ## Parameters

  - `client` - The Turso client
  - `name` - The name of the token to retrieve

  ## Returns

  - `{:ok, token()}` - Token information (without the token value)
  - `{:error, map()}` - Error details

  ## Note

  This endpoint returns metadata about the token but not the actual token value.
  Token values are only provided during creation and cannot be retrieved later.
  """
  @spec retrieve(Turso.t(), String.t()) :: api_result(token())
  def retrieve(%Turso{} = client, name) do
    with {:ok, tokens} <- list(client) do
      case Enum.find(tokens, &(&1["name"] == name)) do
        nil ->
          {:error,
           %{
             "error" => %{
               "type" => "not_found",
               "message" => "Token '#{name}' not found"
             }
           }}

        token ->
          {:ok, token}
      end
    end
  end

  # Private helper functions

  @spec maybe_add_field(map(), String.t(), any()) :: map()
  defp maybe_add_field(map, _key, nil), do: map
  defp maybe_add_field(map, key, value), do: Map.put(map, key, value)
end
