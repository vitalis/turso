defmodule Turso.Error do
  @moduledoc """
  Error handling and representation for Turso API errors.

  This module provides a consistent error structure for all Turso API errors,
  making it easier to handle different error scenarios in your application.

  ## Error Types

  The `:type` field categorizes errors for easier pattern matching:

  - `:unauthorized` - Invalid or missing API token (401)
  - `:forbidden` - Insufficient permissions (403)
  - `:not_found` - Resource not found (404)
  - `:conflict` - Resource already exists (409)
  - `:rate_limited` - Too many requests (429)
  - `:invalid_request` - Bad request parameters (400)
  - `:unprocessable_entity` - Request validation failed (422)
  - `:server_error` - Internal server error (500+)
  - `:network_error` - Connection or network failure
  - `:timeout` - Request timeout
  - `:unknown` - Unrecognized error

  ## Usage

      case Turso.create_database(client, "my-db") do
        {:ok, database} ->
          # Success

        {:error, %Turso.Error{type: :conflict}} ->
          # Database already exists

        {:error, %Turso.Error{type: :rate_limited} = error} ->
          # Rate limited, check error.details for retry info

        {:error, %Turso.Error{} = error} ->
          # Handle other errors
          Logger.error("Turso error: \#{error.message}")
      end
  """

  @type error_type ::
          :unauthorized
          | :forbidden
          | :not_found
          | :conflict
          | :rate_limited
          | :invalid_request
          | :unprocessable_entity
          | :server_error
          | :network_error
          | :timeout
          | :unknown

  @type t :: %__MODULE__{
          type: error_type(),
          message: String.t(),
          status: integer() | nil,
          details: map() | nil,
          request_url: String.t() | nil,
          request_method: atom() | nil
        }

  defexception [:type, :message, :status, :details, :request_url, :request_method]

  @impl true
  def exception(fields) do
    struct!(__MODULE__, fields)
  end

  @impl true
  def message(%__MODULE__{message: message}) do
    message
  end

  @doc """
  Creates a new error from an HTTP response and request information.

  ## Parameters

  - `response` - The response tuple or error data
  - `request_info` - Optional map with request details (:method, :url)

  ## Examples

      Turso.Error.new({:error, %{"status" => 404, "error" => %{"message" => "Not found"}}})

      Turso.Error.new(
        {:error, %{"status" => 401}},
        %{method: :post, url: "/organizations/my-org/databases"}
      )
  """
  @spec new(any(), map()) :: t()
  def new(response, request_info \\ %{})

  def new({:error, %{"status" => status, "error" => error_data}}, request_info)
      when is_map(error_data) do
    %__MODULE__{
      type: status_to_type(status),
      message: extract_message(error_data),
      status: status,
      details: error_data,
      request_url: request_info[:url],
      request_method: request_info[:method]
    }
  end

  def new({:error, %{"status" => status, "error" => message}}, request_info)
      when is_binary(message) do
    %__MODULE__{
      type: status_to_type(status),
      message: message,
      status: status,
      details: nil,
      request_url: request_info[:url],
      request_method: request_info[:method]
    }
  end

  def new({:error, %{"error" => error_data}}, request_info) when is_map(error_data) do
    %__MODULE__{
      type: infer_type(error_data),
      message: extract_message(error_data),
      status: nil,
      details: error_data,
      request_url: request_info[:url],
      request_method: request_info[:method]
    }
  end

  def new({:error, reason}, request_info) when is_binary(reason) do
    %__MODULE__{
      type: :unknown,
      message: reason,
      status: nil,
      details: nil,
      request_url: request_info[:url],
      request_method: request_info[:method]
    }
  end

  def new({:error, :timeout}, request_info) do
    %__MODULE__{
      type: :timeout,
      message: "Request timed out",
      status: nil,
      details: nil,
      request_url: request_info[:url],
      request_method: request_info[:method]
    }
  end

  def new({:error, {:closed, _}}, request_info) do
    %__MODULE__{
      type: :network_error,
      message: "Connection closed unexpectedly",
      status: nil,
      details: nil,
      request_url: request_info[:url],
      request_method: request_info[:method]
    }
  end

  def new({:error, reason}, request_info) do
    %__MODULE__{
      type: :unknown,
      message: "Unknown error: #{inspect(reason)}",
      status: nil,
      details: %{"raw" => reason},
      request_url: request_info[:url],
      request_method: request_info[:method]
    }
  end

  @doc """
  Parses an error response body and status code into an Error struct.

  ## Examples

      Turso.Error.parse(%{"error" => "Database not found"}, 404)
  """
  @spec parse(any(), integer() | nil) :: t()
  def parse(response_body, status \\ nil) do
    new({:error, %{"status" => status, "error" => response_body}})
  end

  @doc """
  Checks if the error is a rate limiting error.

  ## Examples

      if Turso.Error.rate_limited?(error) do
        # Wait before retrying
      end
  """
  @spec rate_limited?(t() | any()) :: boolean()
  def rate_limited?(%__MODULE__{type: :rate_limited}), do: true
  def rate_limited?(_), do: false

  @doc """
  Checks if the error is an authentication/authorization error.

  ## Examples

      if Turso.Error.auth_error?(error) do
        # Refresh token or re-authenticate
      end
  """
  @spec auth_error?(t() | any()) :: boolean()
  def auth_error?(%__MODULE__{type: type}) when type in [:unauthorized, :forbidden], do: true
  def auth_error?(_), do: false

  @doc """
  Checks if the error is a client error (4xx status codes).

  ## Examples

      if Turso.Error.client_error?(error) do
        # Don't retry, fix the request
      end
  """
  @spec client_error?(t() | any()) :: boolean()
  def client_error?(%__MODULE__{status: status}) when status in 400..499, do: true

  def client_error?(%__MODULE__{type: type})
      when type in [
             :invalid_request,
             :unauthorized,
             :forbidden,
             :not_found,
             :conflict,
             :unprocessable_entity,
             :rate_limited
           ],
      do: true

  def client_error?(_), do: false

  @doc """
  Checks if the error is a server error (5xx status codes).

  ## Examples

      if Turso.Error.server_error?(error) do
        # Might be temporary, consider retrying
      end
  """
  @spec server_error?(t() | any()) :: boolean()
  def server_error?(%__MODULE__{status: status}) when status >= 500, do: true
  def server_error?(%__MODULE__{type: :server_error}), do: true
  def server_error?(_), do: false

  @doc """
  Checks if the error might be resolved by retrying.

  Rate limited, timeout, and server errors are typically retryable.

  ## Examples

      if Turso.Error.retryable?(error) do
        # Wait and retry
      end
  """
  @spec retryable?(t() | any()) :: boolean()
  def retryable?(%__MODULE__{type: type})
      when type in [:rate_limited, :timeout, :server_error, :network_error],
      do: true

  def retryable?(%__MODULE__{status: status}) when status >= 500, do: true
  def retryable?(_), do: false

  @doc """
  Extracts retry-after information from rate limiting errors.

  Returns the number of seconds to wait before retrying, or nil if not available.

  ## Examples

      case Turso.Error.retry_after(error) do
        nil -> # No retry info
        seconds -> Process.sleep(seconds * 1000)
      end
  """
  @spec retry_after(t()) :: integer() | nil
  def retry_after(%__MODULE__{type: :rate_limited, details: %{"retry_after" => seconds}})
      when is_integer(seconds) do
    seconds
  end

  def retry_after(%__MODULE__{type: :rate_limited, details: %{"retry-after" => seconds}})
      when is_integer(seconds) do
    seconds
  end

  def retry_after(_), do: nil

  # Private helper functions

  @spec status_to_type(integer() | nil) :: error_type()
  defp status_to_type(nil), do: :unknown
  defp status_to_type(400), do: :invalid_request
  defp status_to_type(401), do: :unauthorized
  defp status_to_type(403), do: :forbidden
  defp status_to_type(404), do: :not_found
  defp status_to_type(409), do: :conflict
  defp status_to_type(422), do: :unprocessable_entity
  defp status_to_type(429), do: :rate_limited
  defp status_to_type(status) when status >= 500, do: :server_error
  defp status_to_type(status) when status >= 400, do: :invalid_request
  defp status_to_type(_), do: :unknown

  @spec extract_message(map()) :: String.t()
  defp extract_message(%{"message" => message}) when is_binary(message), do: message
  defp extract_message(%{"error" => message}) when is_binary(message), do: message

  defp extract_message(%{"errors" => errors}) when is_list(errors) do
    Enum.map_join(errors, ", ", &extract_error_string/1)
  end

  defp extract_message(error_data) do
    "API error: #{inspect(error_data)}"
  end

  @spec extract_error_string(any()) :: String.t()
  defp extract_error_string(%{"message" => message}), do: message
  defp extract_error_string(error) when is_binary(error), do: error
  defp extract_error_string(error), do: inspect(error)

  @spec infer_type(map()) :: error_type()
  defp infer_type(%{"type" => type}) when is_binary(type) do
    case String.downcase(type) do
      "unauthorized" -> :unauthorized
      "forbidden" -> :forbidden
      "not_found" -> :not_found
      "rate_limited" -> :rate_limited
      "server_error" -> :server_error
      _ -> :unknown
    end
  end

  defp infer_type(%{"code" => code}) when is_binary(code) do
    case String.downcase(code) do
      "unauthorized" -> :unauthorized
      "forbidden" -> :forbidden
      "not_found" -> :not_found
      "rate_limit_exceeded" -> :rate_limited
      _ -> :unknown
    end
  end

  defp infer_type(_), do: :unknown
end
