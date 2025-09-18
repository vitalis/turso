defmodule Turso.Locations do
  @moduledoc """
  Location discovery for Turso Cloud Platform.

  This module provides functions for discovering available locations where
  databases and groups can be placed, as well as finding the optimal location
  for your use case.
  """

  alias Turso.{Client, Error}

  @type location :: Turso.location()
  @type api_result(success_type) :: Turso.api_result(success_type)

  @doc """
  Lists all available locations for database and group placement.

  ## Examples

      {:ok, locations} = Turso.Locations.list(client)

  ## Returns

  - `{:ok, list(location())}` - List of available locations with details
  - `{:error, map()}` - Error details

  ## Location Object

  Each location object typically contains:
  - `code` - Location code (e.g., "iad", "lhr", "nrt")
  - `name` - Human-readable name (e.g., "Washington, D.C. (IAD)")
  - `type` - Location type (e.g., "primary", "edge")
  """
  @spec list(Turso.t()) :: api_result(list(map()))
  def list(%Turso{} = client) do
    client
    |> Client.request(:get, "/locations")
    |> Client.handle_response("locations")
  end

  @doc """
  Finds the closest location to the client.

  This function queries the Turso region service to determine the optimal
  location based on network latency from the client's current position.

  ## Examples

      {:ok, closest} = Turso.Locations.closest(client)

  ## Returns

  - `{:ok, String.t() | map()}` - Closest location code or details
  - `{:error, map()}` - Error details

  ## Notes

  This function uses a different endpoint (`region.turso.io`) that doesn't
  require authentication and determines the closest region based on the
  request's origin.
  """
  @spec closest(Turso.t()) :: api_result(String.t() | map())
  def closest(%Turso{} = client) do
    # The region endpoint uses a different base URL and doesn't require auth
    region_req =
      Req.new(
        base_url: "https://region.turso.io",
        headers: [{"content-type", "application/json"}],
        receive_timeout: client.req.options[:receive_timeout] || 30_000
      )

    case Req.request(region_req, method: :get, url: "/") do
      {:ok, %Req.Response{status: status, body: response_body}} when status in 200..299 ->
        {:ok, response_body}

      {:ok, %Req.Response{status: status, body: response_body}} ->
        {:error,
         %{
           "status" => status,
           "error" => Client.format_error_response(response_body)
         }}

      {:error, reason} ->
        {:error,
         %{
           "error" => %{
             "type" => "request_failed",
             "message" => "Failed to determine closest region: #{inspect(reason)}"
           }
         }}
    end
  end

  @doc """
  Gets detailed information about a specific location.

  ## Examples

      {:ok, location} = Turso.Locations.get(client, "iad")

  ## Parameters

  - `client` - The Turso client
  - `location_code` - The location code (e.g., "iad", "lhr")

  ## Returns

  - `{:ok, location()}` - Location details
  - `{:error, map()}` - Error details
  """
  @spec get(Turso.t(), String.t()) :: api_result(location())
  def get(%Turso{} = client, location_code) do
    with {:ok, locations} <- list(client) do
      case Enum.find(locations, &(&1["code"] == location_code)) do
        nil ->
          {:error,
           %Error{
             type: :not_found,
             message: "Location '#{location_code}' not found",
             status: nil,
             details: nil,
             request_url: nil,
             request_method: nil
           }}

        location ->
          {:ok, location}
      end
    end
  end

  @doc """
  Lists available locations grouped by region.

  This is a convenience function that organizes locations by their geographic
  region (e.g., "North America", "Europe", "Asia-Pacific").

  ## Examples

      {:ok, regions} = Turso.Locations.by_region(client)

  ## Returns

  - `{:ok, map()}` - Locations grouped by region
  - `{:error, map()}` - Error details

  ## Example Return Value

      %{
        "North America" => [
          %{"code" => "iad", "name" => "Washington, D.C. (IAD)"},
          %{"code" => "ord", "name" => "Chicago, IL (ORD)"}
        ],
        "Europe" => [
          %{"code" => "lhr", "name" => "London (LHR)"},
          %{"code" => "ams", "name" => "Amsterdam (AMS)"}
        ]
      }
  """
  @spec by_region(Turso.t()) :: api_result(map())
  def by_region(%Turso{} = client) do
    with {:ok, locations} <- list(client) do
      grouped =
        locations
        |> Enum.group_by(&infer_region/1)
        |> Map.new()

      {:ok, grouped}
    end
  end

  # Private helper functions

  @spec infer_region(map()) :: String.t()
  defp infer_region(%{"code" => code}) do
    case code do
      code when code in ~w(iad ord dfw sjc lax sea) ->
        "North America"

      code when code in ~w(lhr ams fra cdg mad) ->
        "Europe"

      code when code in ~w(nrt hnd sin syd) ->
        "Asia-Pacific"

      code when code in ~w(gru scl) ->
        "South America"

      code when code in ~w(jnb) ->
        "Africa"

      _ ->
        "Other"
    end
  end

  defp infer_region(_), do: "Unknown"
end
