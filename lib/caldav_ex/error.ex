defmodule CalDAVEx.Error do
  @moduledoc """
  Error types and utilities for CalDAV operations.

  All CalDAVEx functions return errors as `{:error, %CalDAVEx.Error{}}`.
  """

  @typedoc """
  Error struct.

  ## Fields

  - `type` - The error type (`:transport`, `:http`, `:xml`, `:protocol`, `:not_found`, `:unauthorized`, `:conflict`, `:invalid_argument`)
  - `message` - Human-readable error message
  - `details` - Additional error details (optional)
  """
  @type type ::
          :transport
          | :http
          | :xml
          | :protocol
          | :not_found
          | :unauthorized
          | :conflict
          | :invalid_argument

  @type t :: %__MODULE__{
          type: type(),
          message: String.t() | nil,
          details: term() | nil
        }

  defstruct [:type, :message, :details]

  @doc "Creates a transport error (network/connection issues)"
  @spec transport(String.t()) :: t()
  def transport(msg), do: %__MODULE__{type: :transport, message: msg}

  @doc "Creates an HTTP error with status code and response body"
  @spec http(integer(), term()) :: t()
  def http(status, body), do: %__MODULE__{type: :http, message: "HTTP #{status}", details: body}

  @doc "Creates an XML parsing error"
  @spec xml(String.t()) :: t()
  def xml(msg), do: %__MODULE__{type: :xml, message: msg}

  @doc "Creates a CalDAV protocol error"
  @spec protocol(String.t()) :: t()
  def protocol(msg), do: %__MODULE__{type: :protocol, message: msg}

  @doc "Creates a not found error (HTTP 404)"
  @spec not_found() :: t()
  def not_found, do: %__MODULE__{type: :not_found}

  @doc "Creates an unauthorized error (HTTP 401)"
  @spec unauthorized() :: t()
  def unauthorized, do: %__MODULE__{type: :unauthorized}

  @doc "Creates a conflict error (HTTP 409)"
  @spec conflict() :: t()
  def conflict, do: %__MODULE__{type: :conflict}

  @doc "Creates an invalid-argument error (caller-side validation failure)"
  @spec invalid_argument(String.t()) :: t()
  def invalid_argument(msg), do: %__MODULE__{type: :invalid_argument, message: msg}

  @doc """
  Converts an error to a human-readable string.

  ## Examples

      error = CalDAVEx.Error.http(404, "Not found")
      CalDAVEx.Error.to_string(error)
      # => "[caldav_ex] HTTP error: HTTP 404 - Not found"
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = e), do: "[caldav_ex] " <> describe(e)

  defp describe(%__MODULE__{type: :transport, message: msg}), do: "Transport error: #{msg}"

  defp describe(%__MODULE__{type: :http, message: msg, details: nil}),
    do: "HTTP error: #{msg}"

  defp describe(%__MODULE__{type: :http, message: msg, details: details}),
    do: "HTTP error: #{msg} - #{format_details(details)}"

  defp describe(%__MODULE__{type: :xml, message: msg}), do: "XML error: #{msg}"
  defp describe(%__MODULE__{type: :protocol, message: msg}), do: "Protocol error: #{msg}"
  defp describe(%__MODULE__{type: :not_found}), do: "Not found"
  defp describe(%__MODULE__{type: :unauthorized}), do: "Unauthorized"
  defp describe(%__MODULE__{type: :conflict}), do: "Conflict"

  defp describe(%__MODULE__{type: :invalid_argument, message: msg}),
    do: "Invalid argument: #{msg}"

  defp describe(%__MODULE__{}), do: "Unknown error"

  defp format_details(details) when is_binary(details), do: details
  defp format_details(details), do: inspect(details)
end
