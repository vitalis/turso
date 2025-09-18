defmodule Turso.AuditLogsTest do
  use ExUnit.Case

  describe "list/2" do
    test "returns list of audit logs" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :audit_logs))

      assert {:ok, response} = Turso.AuditLogs.list(client)
      assert response["audit_logs"] |> is_list()
      assert response["page_token"] == nil
      assert response["has_more"] == false

      logs = response["audit_logs"]
      assert length(logs) == 1

      first_log = List.first(logs)
      assert first_log["id"] == "log-123"
      assert first_log["action"] == "database.create"
      assert first_log["actor_email"] == "test@example.com"
    end

    test "handles pagination options" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :audit_logs))

      opts = [
        page_size: 50,
        page_token: "next_page_token",
        order: "asc"
      ]

      assert {:ok, response} = Turso.AuditLogs.list(client, opts)
      assert is_map(response)
    end

    test "handles filtering options" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :audit_logs))

      opts = [
        action: "database.create",
        actor_id: "user-123",
        start_time: "2024-01-01T00:00:00Z",
        end_time: "2024-01-31T23:59:59Z"
      ]

      assert {:ok, response} = Turso.AuditLogs.list(client, opts)
      assert is_map(response)
    end

    test "validates options" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :audit_logs))

      assert_raise NimbleOptions.ValidationError, fn ->
        Turso.AuditLogs.list(client, invalid_option: "value")
      end
    end

    test "handles unauthorized access" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 401))

      assert {:error, %Turso.Error{type: :unauthorized}} = Turso.AuditLogs.list(client)
    end

    test "handles organization option" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :audit_logs))

      assert {:ok, response} = Turso.AuditLogs.list(client, organization: "other-org")
      assert is_map(response)
    end
  end

  describe "retrieve/3" do
    test "retrieves specific audit log entry" do
      client =
        Turso.Mock.client(fn conn ->
          # Return a single audit log entry
          log_entry = %{
            "id" => "log-123",
            "timestamp" => "2024-01-16T12:00:00Z",
            "action" => "database.create",
            "actor_id" => "user-123",
            "actor_email" => "test@example.com",
            "resource_type" => "database",
            "resource_id" => "test-db"
          }

          Turso.Mock.respond(conn, log_entry)
        end)

      assert {:ok, log_entry} = Turso.AuditLogs.retrieve(client, "log-123")
      assert log_entry["id"] == "log-123"
      assert log_entry["action"] == "database.create"
    end

    test "handles not found" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 404))

      assert {:error, %Turso.Error{type: :not_found}} =
               Turso.AuditLogs.retrieve(client, "nonexistent-log")
    end

    test "handles organization option" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 200))

      assert {:ok, _log} = Turso.AuditLogs.retrieve(client, "log-123", organization: "other-org")
    end
  end

  describe "stream/2" do
    test "streams all audit logs with pagination" do
      # Mock multiple pages of results
      call_count = :counters.new(1, [])

      client =
        Turso.Mock.client(fn conn ->
          :counters.add(call_count, 1, 1)
          count = :counters.get(call_count, 1)

          case count do
            1 ->
              # First page with next token
              response = %{
                "audit_logs" => [
                  %{"id" => "log-1", "action" => "database.create"},
                  %{"id" => "log-2", "action" => "database.delete"}
                ],
                "page_token" => "next_page",
                "has_more" => true
              }

              Turso.Mock.respond(conn, response)

            2 ->
              # Second page, final page
              response = %{
                "audit_logs" => [
                  %{"id" => "log-3", "action" => "group.create"}
                ],
                "page_token" => nil,
                "has_more" => false
              }

              Turso.Mock.respond(conn, response)

            _ ->
              Turso.Mock.respond(conn, 404)
          end
        end)

      logs =
        client
        |> Turso.AuditLogs.stream()
        |> Enum.to_list()

      assert length(logs) == 3
      assert Enum.map(logs, & &1["id"]) == ["log-1", "log-2", "log-3"]
    end

    test "streams with filtering options" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, :audit_logs))

      logs =
        client
        |> Turso.AuditLogs.stream(action: "database.create")
        |> Enum.take(1)

      assert length(logs) == 1
    end

    test "handles empty results" do
      client =
        Turso.Mock.client(fn conn ->
          response = %{
            "audit_logs" => [],
            "page_token" => nil,
            "has_more" => false
          }

          Turso.Mock.respond(conn, response)
        end)

      logs =
        client
        |> Turso.AuditLogs.stream()
        |> Enum.to_list()

      assert logs == []
    end

    test "handles API errors gracefully" do
      client = Turso.Mock.client(&Turso.Mock.respond(&1, 401))

      logs =
        client
        |> Turso.AuditLogs.stream()
        |> Enum.to_list()

      # Stream should be empty when API returns error
      assert logs == []
    end
  end
end
