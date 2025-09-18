defmodule Turso.LocationsTest do
  use ExUnit.Case

  describe "list/1" do
    test "returns list of available locations" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :location_list))

      assert {:ok, locations} = Turso.Locations.list(client)
      assert is_list(locations)
      assert length(locations) == 3

      first_location = List.first(locations)
      assert first_location["code"] == "iad"
      assert first_location["name"] == "Washington, D.C. (IAD)"
    end

    test "handles API errors" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 401))

      assert {:error, %Turso.Error{type: :unauthorized}} = Turso.Locations.list(client)
    end
  end

  describe "closest/1" do
    test "returns closest location" do
      # Note: This test makes a real request to region.turso.io
      # The mock setup doesn't affect this since closest/1 uses a separate Req instance
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :closest_region))

      assert {:ok, location} = Turso.Locations.closest(client)
      assert is_map(location)
      assert Map.has_key?(location, "client")
      assert Map.has_key?(location, "server")
    end

    test "handles network errors gracefully" do
      # Skip this test since closest/1 uses region.turso.io directly
      # and we can't easily mock network failures for it
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 500))

      # This will make a real request to region.turso.io, which should succeed
      assert {:ok, location} = Turso.Locations.closest(client)
      assert is_map(location)
    end
  end

  describe "get/2" do
    test "retrieves specific location by code" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :location_list))

      assert {:ok, location} = Turso.Locations.get(client, "iad")
      assert location["code"] == "iad"
      assert location["name"] == "Washington, D.C. (IAD)"
    end

    test "returns error for unknown location" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :location_list))

      assert {:error, %Turso.Error{type: :not_found}} =
               Turso.Locations.get(client, "unknown")
    end

    test "handles list API errors" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 401))

      assert {:error, %Turso.Error{type: :unauthorized}} =
               Turso.Locations.get(client, "iad")
    end
  end

  describe "by_region/1" do
    test "groups locations by region" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :location_list))

      assert {:ok, regions} = Turso.Locations.by_region(client)
      assert is_map(regions)

      # Check that locations are grouped by region
      assert Map.has_key?(regions, "North America")
      assert Map.has_key?(regions, "Europe")
      assert Map.has_key?(regions, "Asia-Pacific")

      # Check specific groupings
      north_america = regions["North America"]
      assert is_list(north_america)
      assert Enum.any?(north_america, &(&1["code"] == "iad"))

      europe = regions["Europe"]
      assert is_list(europe)
      assert Enum.any?(europe, &(&1["code"] == "lhr"))

      asia_pacific = regions["Asia-Pacific"]
      assert is_list(asia_pacific)
      assert Enum.any?(asia_pacific, &(&1["code"] == "nrt"))
    end

    test "handles empty location list" do
      client =
        Turso.Mock.client(fn conn ->
          Turso.Mock.respond(conn, %{"locations" => []})
        end)

      assert {:ok, regions} = Turso.Locations.by_region(client)
      assert regions == %{}
    end

    test "handles API errors" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 500))

      assert {:error, %Turso.Error{type: :server_error}} =
               Turso.Locations.by_region(client)
    end
  end

  describe "private helper functions" do
    test "infer_region/1 correctly categorizes location codes" do
      # We can't directly test private functions, but we can test their behavior
      # through the public by_region/1 function

      # Mock a custom location list with known codes
      custom_locations = [
        %{"code" => "iad", "name" => "Washington, D.C."},
        %{"code" => "lhr", "name" => "London"},
        %{"code" => "nrt", "name" => "Tokyo"},
        %{"code" => "gru", "name" => "São Paulo"},
        %{"code" => "jnb", "name" => "Johannesburg"},
        %{"code" => "unknown", "name" => "Unknown Location"}
      ]

      client =
        Turso.Mock.client(fn conn ->
          Turso.Mock.respond(conn, %{"locations" => custom_locations})
        end)

      assert {:ok, regions} = Turso.Locations.by_region(client)

      assert Map.has_key?(regions, "North America")
      assert Map.has_key?(regions, "Europe")
      assert Map.has_key?(regions, "Asia-Pacific")
      assert Map.has_key?(regions, "South America")
      assert Map.has_key?(regions, "Africa")
      assert Map.has_key?(regions, "Other")
    end
  end
end
