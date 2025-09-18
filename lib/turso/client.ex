defmodule Turso.Client do
  @moduledoc """
  HTTP client utilities for Turso API requests.

  This module provides common functionality for making HTTP requests to the
  Turso Platform API, including path construction, request handling, and
  response processing.
  """

  alias Turso.Error

  @type response :: {:ok, map()} | {:error, Error.t()}

  @doc """
  Constructs an organization-scoped API path.

  If the client has a default organization, it uses that. Otherwise, raises
  an error indicating that an organization is required.

  ## Examples

      iex> client = %Turso{organization: "my-org"}
      iex> Turso.Client.org_path(client, ["databases"])
      "/organizations/my-org/databases"

      iex> client = %Turso{organization: nil}
      iex> Turso.Client.org_path(client, ["databases"], "other-org")
      "/organizations/other-org/databases"

  ## Parameters

  - `client` - The Turso client struct
  - `path_segments` - List of path segments to append
  - `override_org` - Optional organization to use instead of client default

  ## Returns

  A string representing the API path.

  ## Raises

  `ArgumentError` if no organization is available (neither in client nor override).
  """
  @spec org_path(Turso.t(), list(String.t()), String.t() | nil) :: String.t()
  def org_path(%Turso{} = client, path_segments, override_org \\ nil) do
    organization = override_org || client.organization

    if organization do
      Path.join(["/v1/organizations", organization] ++ path_segments)
    else
      raise ArgumentError, """
      Organization is required for this operation.

      Either set a default organization when initializing the client:
        client = Turso.init(token, organization: "my-org")

      Or pass the organization as an option:
        Turso.some_function(client, organization: "my-org")
      """
    end
  end

  @doc """
  Makes an HTTP request using the client's configured Req instance.

  ## Parameters

  - `client` - The Turso client struct
  - `method` - HTTP method (`:get`, `:post`, `:patch`, `:delete`)
  - `path` - URL path (will be appended to base URL)
  - `body` - Request body (optional, will be JSON encoded)
  - `opts` - Additional options like query parameters

  ## Returns

  - `{:ok, response_body}` on success
  - `{:error, reason}` on failure

  ## Examples

      {:ok, data} = Turso.Client.request(client, :get, "/organizations/my-org/databases")

      {:ok, data} = Turso.Client.request(client, :post, "/organizations/my-org/databases", %{
        "name" => "my-db",
        "group" => "default"
      })
  """
  @spec request(Turso.t(), atom(), String.t(), map() | nil, keyword()) :: response()
  def request(%Turso{req: req}, method, path, body \\ nil, opts \\ []) do
    # Handle query parameters
    req_opts =
      case Keyword.get(opts, :params) do
        nil -> []
        params -> [params: params]
      end

    # Make the request
    req_options = [method: method, url: path, json: body] ++ req_opts

    case Req.request(req, req_options) do
      {:ok, %Req.Response{status: status, body: response_body}} when status in 200..299 ->
        {:ok, response_body}

      {:ok, %Req.Response{status: status, body: response_body}} ->
        request_info = %{method: method, url: path}
        error_response = %{"status" => status, "error" => format_error_response(response_body)}
        {:error, Error.new({:error, error_response}, request_info)}

      {:error, reason} ->
        request_info = %{method: method, url: path}
        {:error, Error.new({:error, reason}, request_info)}
    end
  end

  @doc """
  Handles API response and extracts data from standard Turso response format.

  Many Turso API endpoints return data wrapped in a container object.
  This function extracts the actual data from common response patterns.

  ## Parameters

  - `response` - The response tuple from `request/5`
  - `data_key` - Optional key to extract from response (e.g., "databases")

  ## Returns

  - `{:ok, data}` on success
  - `{:error, reason}` on failure

  ## Examples

      # Extract "databases" array from response
      {:ok, databases} =
        client
        |> Turso.Client.request(:get, "/organizations/my-org/databases")
        |> Turso.Client.handle_response("databases")

      # Return response as-is
      {:ok, database} =
        client
        |> Turso.Client.request(:post, "/organizations/my-org/databases", body)
        |> Turso.Client.handle_response()
  """
  @spec handle_response(response(), String.t() | nil) :: response()
  def handle_response(response, data_key \\ nil)

  def handle_response({:ok, data}, nil), do: {:ok, data}

  def handle_response({:ok, data}, data_key) when is_map(data) do
    case Map.get(data, data_key) do
      nil -> {:ok, data}
      extracted_data -> {:ok, extracted_data}
    end
  end

  def handle_response({:error, %Error{}} = error, _data_key), do: error

  @doc """
  Formats error responses from the Turso API into a consistent structure.

  ## Parameters

  - `response_body` - The response body from the API

  ## Returns

  A map with consistent error structure.
  """
  @spec format_error_response(any()) :: map()
  def format_error_response(response_body) when is_map(response_body) do
    # Turso API typically returns errors in this format:
    # {"error": {"code": "...", "message": "..."}}
    # or
    # {"error": "error message"}
    case response_body do
      %{"error" => error} when is_map(error) -> error
      %{"error" => error} when is_binary(error) -> %{"message" => error}
      %{"message" => message} -> %{"message" => message}
      other -> %{"message" => "Unknown error", "details" => other}
    end
  end

  def format_error_response(response_body) when is_binary(response_body) do
    %{"message" => response_body}
  end

  def format_error_response(other) do
    %{"message" => "Unknown error format", "details" => inspect(other)}
  end
end
