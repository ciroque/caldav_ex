defmodule CalDAVEx.Auth do
  @moduledoc """
  Builds HTTP `Authorization` headers from auth configuration tuples.

  Auth tuples are produced by the helpers on the top-level `CalDAVEx`
  module (`CalDAVEx.no_auth/0`, `CalDAVEx.basic_auth/2`,
  `CalDAVEx.bearer_auth/1`) and stored on `CalDAVEx.Config`. This module
  converts those tuples into the header list passed to the underlying HTTP
  client.
  """

  @doc """
  Returns the list of HTTP headers required to authenticate a request.

  ## Parameters

    - `auth` - an auth tuple:
      - `:no_auth` - no authentication; returns `[]`
      - `{:basic, username, password}` - HTTP Basic; Base64-encodes `username:password`
      - `{:bearer, token}` - Bearer token

  ## Examples

      iex> CalDAVEx.Auth.to_headers(:no_auth)
      []

      iex> CalDAVEx.Auth.to_headers({:bearer, "abc"})
      [{"authorization", "Bearer abc"}]
  """
  @spec to_headers(CalDAVEx.Config.auth()) :: [{String.t(), String.t()}]
  def to_headers(:no_auth), do: []

  def to_headers({:basic, username, password}) do
    credentials = Base.encode64("#{username}:#{password}")
    [{"authorization", "Basic #{credentials}"}]
  end

  def to_headers({:bearer, token}) do
    [{"authorization", "Bearer #{token}"}]
  end
end
