defmodule CalDAVEx.Client do
  @moduledoc """
  CalDAV client struct used to execute requests against a server.

  A `Client` wraps a `CalDAVEx.Config` and is the value threaded through every
  request-issuing function in the library. Prefer constructing clients via the
  top-level `CalDAVEx.new_client/1` helper.
  """

  defstruct [:config]

  @doc """
  Builds a new client from a `CalDAVEx.Config` struct.

  ## Parameters

    - `config` - a `%CalDAVEx.Config{}` produced by `CalDAVEx.new_config/2`

  ## Examples

      config = CalDAVEx.new_config("https://caldav.example.com", CalDAVEx.no_auth())
      client = CalDAVEx.Client.new(config)
  """
  def new(config), do: %__MODULE__{config: config}
end
