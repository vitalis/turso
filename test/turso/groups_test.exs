defmodule Turso.GroupsTest do
  use ExUnit.Case

  describe "list/2" do
    test "returns list of groups" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :group_list))

      assert {:ok, groups} = Turso.Groups.list(client)
      assert is_list(groups)
      assert length(groups) == 2

      first_group = List.first(groups)
      assert first_group["name"] == "default"
      assert first_group["primary_region"] == "iad"
    end

    test "handles organization option" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :group_list))

      assert {:ok, groups} = Turso.Groups.list(client, organization: "other-org")
      assert is_list(groups)
    end
  end

  describe "create/3" do
    test "creates group with auto-selected location" do
      # Mock closest location call and group creation
      client =
        Turso.Mock.client(
          Turso.Mock.request_router(%{
            "GET /" => :closest_region,
            "POST /v1/organizations/test-org/groups" => :group_create
          })
        )

      assert {:ok, group} = Turso.Groups.create(client, "new-group")
      assert group["group"]["name"] == "new-group"
    end

    test "creates group with specific location" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :group_create))

      assert {:ok, group} = Turso.Groups.create(client, "new-group", location: "lhr")
      assert is_map(group)
    end

    test "handles conflict error" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 409))

      assert {:error, %Turso.Error{type: :conflict}} =
               Turso.Groups.create(client, "existing-group")
    end
  end

  describe "retrieve/3" do
    test "retrieves group details" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :group_create))

      assert {:ok, group} = Turso.Groups.retrieve(client, "production")
      assert is_map(group)
    end

    test "handles not found" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 404))

      assert {:error, %Turso.Error{type: :not_found}} =
               Turso.Groups.retrieve(client, "nonexistent-group")
    end
  end

  describe "delete/3" do
    test "deletes group" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 200))

      assert {:ok, _result} = Turso.Groups.delete(client, "old-group")
    end

    test "handles not found" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 404))

      assert {:error, %Turso.Error{type: :not_found}} =
               Turso.Groups.delete(client, "nonexistent-group")
    end
  end

  describe "add_location/4" do
    test "adds location to group" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :group_create))

      assert {:ok, group} = Turso.Groups.add_location(client, "production", "lhr")
      assert is_map(group)
    end

    test "handles invalid location" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 400))

      assert {:error, %Turso.Error{type: :invalid_request}} =
               Turso.Groups.add_location(client, "production", "invalid")
    end
  end

  describe "remove_location/4" do
    test "removes location from group" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :group_create))

      assert {:ok, group} = Turso.Groups.remove_location(client, "production", "lhr")
      assert is_map(group)
    end

    test "handles cannot remove primary location" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 400))

      assert {:error, %Turso.Error{type: :invalid_request}} =
               Turso.Groups.remove_location(client, "production", "iad")
    end
  end

  describe "ensure_exists/3" do
    test "returns :exists when group already exists" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :group_create))

      assert {:ok, :exists} = Turso.Groups.ensure_exists(client, "existing-group")
    end

    test "creates group and returns :created when group doesn't exist" do
      # First call returns 404, second call creates the group
      call_count = :counters.new(1, [])

      client =
        Turso.Mock.client(fn conn ->
          :counters.add(call_count, 1, 1)
          count = :counters.get(call_count, 1)

          case count do
            # GET group returns not found
            1 -> Turso.Mock.respond(conn, 404)
            # POST creates group
            _ -> Turso.Mock.respond(conn, :group_create)
          end
        end)

      assert {:ok, :created} = Turso.Groups.ensure_exists(client, "new-group")
    end

    test "propagates other errors" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 401))

      assert {:error, %Turso.Error{type: :unauthorized}} =
               Turso.Groups.ensure_exists(client, "group")
    end
  end
end
