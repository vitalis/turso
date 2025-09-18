defmodule Turso.TokensTest do
  use ExUnit.Case

  describe "list/1" do
    test "returns list of API tokens" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :token_list))

      assert {:ok, tokens} = Turso.Tokens.list(client)
      assert is_list(tokens)
      assert length(tokens) == 1

      first_token = List.first(tokens)
      assert first_token["name"] == "test-token"
      assert first_token["id"] == "token-id-123"
      assert first_token["created_at"] == "2024-01-01T00:00:00Z"
    end

    test "handles unauthorized access" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 401))

      assert {:error, %Turso.Error{type: :unauthorized}} = Turso.Tokens.list(client)
    end
  end

  describe "create/3" do
    test "creates new API token" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :token_create))

      assert {:ok, token} = Turso.Tokens.create(client, "my-new-token")
      assert token["token"]["name"] == "new-token"
      assert token["token"]["id"] == "token-id-456"
      assert token["token"]["token"] == "test_api_token_value_here"
    end

    test "creates token with description" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :token_create))

      assert {:ok, token} = Turso.Tokens.create(client, "my-token", description: "For CI/CD")
      assert is_map(token)
    end

    test "handles conflict for duplicate token name" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 409))

      assert {:error, %Turso.Error{type: :conflict}} =
               Turso.Tokens.create(client, "existing-token")
    end

    test "validates options" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :token_create))

      assert_raise NimbleOptions.ValidationError, fn ->
        Turso.Tokens.create(client, "token", invalid_option: "value")
      end
    end
  end

  describe "validate/1" do
    test "validates current API token" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :token_validate))

      assert {:ok, validation} = Turso.Tokens.validate(client)
      assert validation["exp"] == 1_735_689_600
      assert validation["id"] == "token-id-123"
    end

    test "handles invalid token" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 401))

      assert {:error, %Turso.Error{type: :unauthorized}} = Turso.Tokens.validate(client)
    end
  end

  describe "revoke/2" do
    test "revokes API token" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 200))

      assert {:ok, _result} = Turso.Tokens.revoke(client, "old-token")
    end

    test "handles token not found" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 404))

      assert {:error, %Turso.Error{type: :not_found}} =
               Turso.Tokens.revoke(client, "nonexistent-token")
    end

    test "handles cannot revoke current token" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 400))

      assert {:error, %Turso.Error{type: :invalid_request}} =
               Turso.Tokens.revoke(client, "current-token")
    end
  end

  describe "retrieve/2" do
    test "retrieves token information by name" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :token_list))

      assert {:ok, token} = Turso.Tokens.retrieve(client, "test-token")
      assert token["name"] == "test-token"
      assert token["id"] == "token-id-123"
    end

    test "handles token not found" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :token_list))

      assert {:error, error} = Turso.Tokens.retrieve(client, "nonexistent-token")
      assert error["error"]["type"] == "not_found"
      assert error["error"]["message"] =~ "nonexistent-token"
    end

    test "handles list API errors" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 401))

      assert {:error, %Turso.Error{type: :unauthorized}} =
               Turso.Tokens.retrieve(client, "test-token")
    end
  end
end
