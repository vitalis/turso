defmodule Turso.ErrorTest do
  use ExUnit.Case

  describe "new/2" do
    test "creates error from HTTP response with status and error data" do
      response = {:error, %{"status" => 404, "error" => %{"message" => "Not found"}}}
      request_info = %{method: :get, url: "/test"}

      error = Turso.Error.new(response, request_info)

      assert %Turso.Error{} = error
      assert error.type == :not_found
      assert error.message == "Not found"
      assert error.status == 404
      assert error.request_method == :get
      assert error.request_url == "/test"
    end

    test "creates error from HTTP response with status and error string" do
      response = {:error, %{"status" => 401, "error" => "Unauthorized"}}
      request_info = %{method: :post, url: "/test"}

      error = Turso.Error.new(response, request_info)

      assert error.type == :unauthorized
      assert error.message == "Unauthorized"
      assert error.status == 401
    end

    test "creates error from error data without status" do
      response = {:error, %{"error" => %{"message" => "Something went wrong"}}}

      error = Turso.Error.new(response)

      assert error.type == :unknown
      assert error.message == "Something went wrong"
      assert error.status == nil
    end

    test "creates error from timeout" do
      response = {:error, :timeout}
      request_info = %{method: :get, url: "/test"}

      error = Turso.Error.new(response, request_info)

      assert error.type == :timeout
      assert error.message == "Request timed out"
    end

    test "creates error from connection closed" do
      response = {:error, {:closed, :some_reason}}
      request_info = %{method: :get, url: "/test"}

      error = Turso.Error.new(response, request_info)

      assert error.type == :network_error
      assert error.message == "Connection closed unexpectedly"
    end

    test "creates error from unknown reason" do
      response = {:error, %{some: "unknown error"}}

      error = Turso.Error.new(response)

      assert error.type == :unknown
      assert error.message =~ "Unknown error"
      assert error.details["raw"] == %{some: "unknown error"}
    end
  end

  describe "status_to_type/1" do
    test "maps common HTTP status codes to error types" do
      assert Turso.Error.new({:error, %{"status" => 400, "error" => "Bad request"}}).type ==
               :invalid_request

      assert Turso.Error.new({:error, %{"status" => 401, "error" => "Unauthorized"}}).type ==
               :unauthorized

      assert Turso.Error.new({:error, %{"status" => 403, "error" => "Forbidden"}}).type ==
               :forbidden

      assert Turso.Error.new({:error, %{"status" => 404, "error" => "Not found"}}).type ==
               :not_found

      assert Turso.Error.new({:error, %{"status" => 409, "error" => "Conflict"}}).type ==
               :conflict

      assert Turso.Error.new({:error, %{"status" => 422, "error" => "Unprocessable entity"}}).type ==
               :unprocessable_entity

      assert Turso.Error.new({:error, %{"status" => 429, "error" => "Rate limited"}}).type ==
               :rate_limited

      assert Turso.Error.new({:error, %{"status" => 500, "error" => "Server error"}}).type ==
               :server_error

      assert Turso.Error.new({:error, %{"status" => 502, "error" => "Bad gateway"}}).type ==
               :server_error
    end
  end

  describe "helper functions" do
    test "rate_limited?/1 identifies rate limit errors" do
      rate_error = Turso.Error.new({:error, %{"status" => 429, "error" => "Rate limited"}})
      other_error = Turso.Error.new({:error, %{"status" => 404, "error" => "Not found"}})

      assert Turso.Error.rate_limited?(rate_error)
      refute Turso.Error.rate_limited?(other_error)
      refute Turso.Error.rate_limited?("not an error")
    end

    test "auth_error?/1 identifies authentication errors" do
      unauth_error = Turso.Error.new({:error, %{"status" => 401, "error" => "Unauthorized"}})
      forbidden_error = Turso.Error.new({:error, %{"status" => 403, "error" => "Forbidden"}})
      other_error = Turso.Error.new({:error, %{"status" => 404, "error" => "Not found"}})

      assert Turso.Error.auth_error?(unauth_error)
      assert Turso.Error.auth_error?(forbidden_error)
      refute Turso.Error.auth_error?(other_error)
    end

    test "client_error?/1 identifies client errors" do
      client_error = Turso.Error.new({:error, %{"status" => 400, "error" => "Bad request"}})
      server_error = Turso.Error.new({:error, %{"status" => 500, "error" => "Server error"}})

      assert Turso.Error.client_error?(client_error)
      refute Turso.Error.client_error?(server_error)
    end

    test "server_error?/1 identifies server errors" do
      server_error = Turso.Error.new({:error, %{"status" => 500, "error" => "Server error"}})
      client_error = Turso.Error.new({:error, %{"status" => 400, "error" => "Bad request"}})

      assert Turso.Error.server_error?(server_error)
      refute Turso.Error.server_error?(client_error)
    end

    test "retryable?/1 identifies retryable errors" do
      rate_error = Turso.Error.new({:error, %{"status" => 429, "error" => "Rate limited"}})
      server_error = Turso.Error.new({:error, %{"status" => 500, "error" => "Server error"}})
      timeout_error = Turso.Error.new({:error, :timeout})
      client_error = Turso.Error.new({:error, %{"status" => 400, "error" => "Bad request"}})

      assert Turso.Error.retryable?(rate_error)
      assert Turso.Error.retryable?(server_error)
      assert Turso.Error.retryable?(timeout_error)
      refute Turso.Error.retryable?(client_error)
    end

    test "retry_after/1 extracts retry-after information" do
      error_with_retry =
        Turso.Error.new({:error, %{"status" => 429, "error" => %{"retry_after" => 60}}})

      error_with_retry_header =
        Turso.Error.new({:error, %{"status" => 429, "error" => %{"retry-after" => 30}}})

      error_without_retry = Turso.Error.new({:error, %{"status" => 429}})

      assert Turso.Error.retry_after(error_with_retry) == 60
      assert Turso.Error.retry_after(error_with_retry_header) == 30
      assert Turso.Error.retry_after(error_without_retry) == nil
    end
  end

  describe "parse/2" do
    test "parses error response with status" do
      error = Turso.Error.parse(%{"error" => "Database not found"}, 404)

      assert error.type == :not_found
      assert error.status == 404
      assert error.message == "Database not found"
    end

    test "parses error response without status" do
      error = Turso.Error.parse(%{"error" => "Something went wrong"})

      assert error.type == :unknown
      assert error.status == nil
    end
  end

  describe "Exception behaviour" do
    test "implements Exception.message/1" do
      error = Turso.Error.new({:error, %{"status" => 404, "error" => "Not found"}})

      assert Exception.message(error) == "Not found"
    end

    test "can be raised as exception" do
      assert_raise Turso.Error, "Not found", fn ->
        raise Turso.Error.new({:error, %{"status" => 404, "error" => "Not found"}})
      end
    end
  end
end
