defmodule Turso.DatabasesTest do
  use ExUnit.Case

  describe "list/2" do
    test "returns list of databases" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :database_list))

      assert {:ok, databases} = Turso.Databases.list(client)
      assert is_list(databases)
      assert length(databases) == 2

      first_db = List.first(databases)
      assert first_db["Name"] == "test-db-1"
      assert first_db["DbId"] == "db-id-123"
    end

    test "handles organization option" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :database_list))

      assert {:ok, databases} = Turso.Databases.list(client, organization: "other-org")
      assert is_list(databases)
    end

    test "validates options" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :database_list))

      assert_raise NimbleOptions.ValidationError, fn ->
        Turso.Databases.list(client, invalid_option: "value")
      end
    end

    test "handles API errors" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 401))

      assert {:error, %Turso.Error{type: :unauthorized}} = Turso.Databases.list(client)
    end
  end

  describe "create/3" do
    test "creates database with defaults" do
      # Mock group exists check and database creation
      client =
        Turso.Mock.client(fn conn ->
          case {conn.method, conn.request_path} do
            {"GET", "/v1/organizations/test-org/groups/default"} ->
              # Return group exists
              group = %{
                "name" => "default",
                "primary_region" => "iad",
                "regions" => ["iad"],
                "archived" => false,
                "uuid" => "group-uuid-123"
              }

              Turso.Mock.respond(conn, group)

            {"POST", "/v1/organizations/test-org/databases"} ->
              Turso.Mock.respond(conn, :database_create)

            _ ->
              Turso.Mock.respond(conn, 404)
          end
        end)

      assert {:ok, database} = Turso.Databases.create(client, "my-new-db")
      assert database["database"]["Name"] == "new-test-db"
    end

    test "creates database with custom group" do
      client =
        Turso.Mock.client(fn conn ->
          case {conn.method, conn.request_path} do
            {"GET", "/v1/organizations/test-org/groups/production"} ->
              # Return group exists
              group = %{
                "name" => "production",
                "primary_region" => "lhr",
                "regions" => ["lhr", "iad"],
                "archived" => false,
                "uuid" => "group-uuid-456"
              }

              Turso.Mock.respond(conn, group)

            {"POST", "/v1/organizations/test-org/databases"} ->
              Turso.Mock.respond(conn, :database_create)

            _ ->
              Turso.Mock.respond(conn, 404)
          end
        end)

      assert {:ok, database} = Turso.Databases.create(client, "my-new-db", group: "production")
      assert is_map(database)
    end

    test "creates database with options" do
      client =
        Turso.Mock.client(fn conn ->
          case {conn.method, conn.request_path} do
            {"GET", "/v1/organizations/test-org/groups/default"} ->
              # Return group exists
              group = %{
                "name" => "default",
                "primary_region" => "iad",
                "regions" => ["iad"],
                "archived" => false,
                "uuid" => "group-uuid-123"
              }

              Turso.Mock.respond(conn, group)

            {"POST", "/v1/organizations/test-org/databases"} ->
              Turso.Mock.respond(conn, :database_create)

            _ ->
              Turso.Mock.respond(conn, 404)
          end
        end)

      opts = [
        group: "default",
        size_limit: "1gb",
        is_schema: true
      ]

      assert {:ok, database} = Turso.Databases.create(client, "schema-db", opts)
      assert is_map(database)
    end

    test "handles conflict error" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 409))

      assert {:error, %Turso.Error{type: :conflict}} =
               Turso.Databases.create(client, "existing-db")
    end
  end

  describe "retrieve/3" do
    test "retrieves database details" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :database_create))

      assert {:ok, database} = Turso.Databases.retrieve(client, "test-db")
      assert is_map(database)
    end

    test "handles not found" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 404))

      assert {:error, %Turso.Error{type: :not_found}} =
               Turso.Databases.retrieve(client, "nonexistent-db")
    end
  end

  describe "delete/3" do
    test "deletes database" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 200))

      assert {:ok, _result} = Turso.Databases.delete(client, "test-db")
    end

    test "handles not found" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 404))

      assert {:error, %Turso.Error{type: :not_found}} =
               Turso.Databases.delete(client, "nonexistent-db")
    end
  end

  describe "create_token/3" do
    test "creates database token" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :database_token))

      assert {:ok, token} = Turso.Databases.create_token(client, "test-db")
      assert token["jwt"] =~ "eyJ0eXAiOiJKV1QiLCJhbGciOiJFZERTQSJ9"
    end

    test "creates token with options" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :database_token))

      opts = [
        expiration: "1w",
        authorization: "read-only"
      ]

      assert {:ok, token} = Turso.Databases.create_token(client, "test-db", opts)
      assert is_map(token)
    end

    test "handles database not found" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 404))

      assert {:error, %Turso.Error{type: :not_found}} =
               Turso.Databases.create_token(client, "nonexistent-db")
    end
  end

  describe "invalidate_tokens/3" do
    test "invalidates all tokens" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 200))

      assert {:ok, _result} = Turso.Databases.invalidate_tokens(client, "test-db")
    end
  end

  describe "update/3" do
    test "updates database configuration" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :database_create))

      opts = [
        allow_attach: true,
        size_limit: "2gb"
      ]

      assert {:ok, database} = Turso.Databases.update(client, "test-db", opts)
      assert is_map(database)
    end
  end
end
