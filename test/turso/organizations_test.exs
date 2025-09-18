defmodule Turso.OrganizationsTest do
  use ExUnit.Case

  describe "list/1" do
    test "returns list of organizations" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :organization_list))

      assert {:ok, organizations} = Turso.Organizations.list(client)
      assert is_list(organizations)
      assert length(organizations) == 1

      first_org = List.first(organizations)
      assert first_org["name"] == "Test Organization"
      assert first_org["slug"] == "test-org"
      assert first_org["type"] == "personal"
      assert first_org["blocked"] == false
    end

    test "handles API errors" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 401))

      assert {:error, %Turso.Error{type: :unauthorized}} = Turso.Organizations.list(client)
    end

    test "handles rate limiting" do
      client = Turso.Mock.client(&Turso.Mock.respond_rate_limited(&1, 30))

      assert {:error, %Turso.Error{type: :rate_limited}} = Turso.Organizations.list(client)
    end
  end

  describe "retrieve/2" do
    test "retrieves specific organization" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :organization_detail))

      assert {:ok, organization} = Turso.Organizations.retrieve(client, "test-org")
      assert organization["organization"]["name"] == "Test Organization"
      assert organization["organization"]["slug"] == "test-org"
    end

    test "handles not found" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 404))

      assert {:error, %Turso.Error{type: :not_found}} =
               Turso.Organizations.retrieve(client, "nonexistent-org")
    end

    test "handles forbidden access" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 403))

      assert {:error, %Turso.Error{type: :forbidden}} =
               Turso.Organizations.retrieve(client, "private-org")
    end
  end

  describe "usage/2" do
    test "retrieves organization usage statistics" do
      usage_data = %{
        "databases" => 5,
        "storage_bytes" => 1_000_000,
        "bandwidth_bytes" => 500_000,
        "requests" => 10_000
      }

      client =
        Turso.Mock.client(fn conn ->
          Turso.Mock.respond(conn, usage_data)
        end)

      assert {:ok, usage} = Turso.Organizations.usage(client, "test-org")
      assert usage["databases"] == 5
      assert usage["storage_bytes"] == 1_000_000
    end

    test "handles unauthorized access" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 401))

      assert {:error, %Turso.Error{type: :unauthorized}} =
               Turso.Organizations.usage(client, "test-org")
    end
  end

  describe "limits/2" do
    test "retrieves organization limits and quotas" do
      limits_data = %{
        "max_databases" => 100,
        "max_storage_bytes" => 10_000_000_000,
        "max_bandwidth_bytes" => 1_000_000_000,
        "current_databases" => 5,
        "current_storage_bytes" => 1_000_000
      }

      client =
        Turso.Mock.client(fn conn ->
          Turso.Mock.respond(conn, limits_data)
        end)

      assert {:ok, limits} = Turso.Organizations.limits(client, "test-org")
      assert limits["max_databases"] == 100
      assert limits["current_databases"] == 5
    end

    test "handles not found organization" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 404))

      assert {:error, %Turso.Error{type: :not_found}} =
               Turso.Organizations.limits(client, "nonexistent-org")
    end
  end

  describe "subscription/2" do
    test "retrieves organization subscription information" do
      subscription_data = %{
        "plan" => "pro",
        "status" => "active",
        "billing_period" => "monthly",
        "next_billing_date" => "2024-02-01T00:00:00Z",
        "limits" => %{
          "databases" => 100,
          "storage_gb" => 1000
        }
      }

      client =
        Turso.Mock.client(fn conn ->
          Turso.Mock.respond(conn, subscription_data)
        end)

      assert {:ok, subscription} = Turso.Organizations.subscription(client, "test-org")
      assert subscription["plan"] == "pro"
      assert subscription["status"] == "active"
      assert subscription["limits"]["databases"] == 100
    end

    test "handles forbidden access to subscription info" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 403))

      assert {:error, %Turso.Error{type: :forbidden}} =
               Turso.Organizations.subscription(client, "test-org")
    end
  end
end
