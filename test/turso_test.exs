defmodule TursoTest do
  use ExUnit.Case
  doctest Turso

  describe "init/2" do
    test "creates client with API token" do
      token = "test_token"
      client = Turso.init(token)

      assert %Turso{api_token: ^token} = client
      assert client.base_url == "https://api.turso.tech/v1"
      assert client.organization == nil
      assert is_struct(client.req, Req.Request)
    end

    test "creates client with organization" do
      token = "test_token"
      org = "test-org"
      client = Turso.init(token, organization: org)

      assert client.organization == org
    end

    test "creates client with custom base_url" do
      token = "test_token"
      custom_url = "https://custom.api.com/v1"
      client = Turso.init(token, base_url: custom_url)

      assert client.base_url == custom_url
    end

    test "creates client with custom timeout" do
      token = "test_token"
      timeout = 60_000
      client = Turso.init(token, receive_timeout: timeout)

      assert client.req.options[:receive_timeout] == timeout
    end

    test "validates options with NimbleOptions" do
      token = "test_token"

      assert_raise NimbleOptions.ValidationError, fn ->
        Turso.init(token, invalid_option: "value")
      end
    end
  end

  describe "delegation functions" do
    setup do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :database_list))
      %{client: client}
    end

    test "list_databases/1 delegates to Turso.Databases.list/1", %{client: client} do
      assert {:ok, databases} = Turso.list_databases(client)
      assert is_list(databases)
    end

    test "create_database/3 delegates to Turso.Databases.create/3", %{client: _client} do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :database_create))
      assert {:ok, database} = Turso.create_database(client, "test-db")
      assert is_map(database)
    end

    test "retrieve_database/2 delegates to Turso.Databases.retrieve/2", %{client: _client} do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :database_create))
      assert {:ok, database} = Turso.retrieve_database(client, "test-db")
      assert is_map(database)
    end

    test "delete_database/2 delegates to Turso.Databases.delete/2", %{client: _client} do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 200))
      assert {:ok, _result} = Turso.delete_database(client, "test-db")
    end

    test "create_database_token/3 delegates to Turso.Databases.create_token/3", %{client: _client} do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :database_token))
      assert {:ok, token} = Turso.create_database_token(client, "test-db")
      assert is_map(token)
    end

    test "list_groups/1 delegates to Turso.Groups.list/1", %{client: _client} do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :group_list))
      assert {:ok, groups} = Turso.list_groups(client)
      assert is_list(groups)
    end

    test "create_group/3 delegates to Turso.Groups.create/3", %{client: _client} do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :group_create))
      assert {:ok, group} = Turso.create_group(client, "test-group")
      assert is_map(group)
    end

    test "list_organizations/1 delegates to Turso.Organizations.list/1", %{client: _client} do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :organization_list))
      assert {:ok, orgs} = Turso.list_organizations(client)
      assert is_list(orgs)
    end

    test "list_locations/1 delegates to Turso.Locations.list/1", %{client: _client} do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :location_list))
      assert {:ok, locations} = Turso.list_locations(client)
      assert is_list(locations)
    end
  end

  describe "error handling" do
    test "handles API errors" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 404))
      assert {:error, %Turso.Error{type: :not_found}} = Turso.list_databases(client)
    end

    test "handles rate limiting" do
      client = Turso.Mock.client(&Turso.Mock.respond_rate_limited(&1, 60))
      assert {:error, %Turso.Error{type: :rate_limited}} = Turso.list_databases(client)
    end
  end
end
