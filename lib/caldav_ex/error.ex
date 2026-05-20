defmodule CalDAVEx.Error do
  @moduledoc """
  Error types and utilities for CalDAV operations.

  All CalDAVEx functions return errors as `{:error, %CalDAVEx.Error{}}`.
  """

  @typedoc """
  Error struct.

  ## Fields

  - `type` - The error type (`:transport`, `:http`, `:xml`, `:protocol`, `:not_found`, `:unauthorized`, `:conflict`)
  - `message` - Human-readable error message
  - `details` - Additional error details (optional)
  """
  @type t :: %__MODULE__{
          type: atom(),
          message: String.t() | nil,
          details: String.t() | nil
        }

  defstruct [:type, :message, :details]

  @doc "Creates a transport error (network/connection issues)"
  def transport(msg), do: %__MODULE__{type: :transport, message: msg}

  @doc "Creates an HTTP error with status code and response body"
  def http(status, body), do: %__MODULE__{type: :http, message: "HTTP #{status}", details: body}

  @doc "Creates an XML parsing error"
  def xml(msg), do: %__MODULE__{type: :xml, message: msg}

  @doc "Creates a CalDAV protocol error"
  def protocol(msg), do: %__MODULE__{type: :protocol, message: msg}

  @doc "Creates a not found error (HTTP 404)"
  def not_found, do: %__MODULE__{type: :not_found}

  @doc "Creates an unauthorized error (HTTP 401)"
  def unauthorized, do: %__MODULE__{type: :unauthorized}

  @doc "Creates a conflict error (HTTP 409)"
  def conflict, do: %__MODULE__{type: :conflict}

  @doc """
  Converts an error to a human-readable string.

  ## Examples

      error = CalDAVEx.Error.http(404, "Not found")
      CalDAVEx.Error.to_string(error)
      # => "[caldav_ex] HTTP error: HTTP 404 - Not found"
  """
  def to_string(%__MODULE__{} = e) do
    "[caldav_ex] " <>
      case e.type do
        :transport -> "Transport error: #{e.message}"
        :http -> "HTTP error: #{e.message} - #{e.details}"
        :xml -> "XML error: #{e.message}"
        :protocol -> "Protocol error: #{e.message}"
        :not_found -> "Not found"
        :unauthorized -> "Unauthorized"
        :conflict -> "Conflict"
        _ -> "Unknown error"
      end
  end
end