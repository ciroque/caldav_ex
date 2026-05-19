defmodule CalDAVEx.Error do
  defstruct [:type, :message, :details]

  def transport(msg), do: %__MODULE__{type: :transport, message: msg}
  def http(status, body), do: %__MODULE__{type: :http, message: "HTTP #{status}", details: body}
  def xml(msg), do: %__MODULE__{type: :xml, message: msg}
  def protocol(msg), do: %__MODULE__{type: :protocol, message: msg}
  def not_found, do: %__MODULE__{type: :not_found}
  def unauthorized, do: %__MODULE__{type: :unauthorized}
  def conflict, do: %__MODULE__{type: :conflict}

  def to_string(%__MODULE__{} = e) do
    "[caldav_ex] " <> case e.type do
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