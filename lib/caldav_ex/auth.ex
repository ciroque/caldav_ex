defmodule CalDAVEx.Auth do
  @moduledoc """
  Authentication header generation for CalDAV requests.
  """

  def to_headers(:no_auth), do: []

  def to_headers({:basic, username, password}) do
    credentials = Base.encode64("#{username}:#{password}")
    [{"authorization", "Basic #{credentials}"}]
  end

  def to_headers({:bearer, token}) do
    [{"authorization", "Bearer #{token}"}]
  end
end
