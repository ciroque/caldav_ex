defmodule CalDAVEx.AuthTest do
  use ExUnit.Case, async: true

  alias CalDAVEx.Auth

  test "no_auth returns empty headers" do
    assert Auth.to_headers(:no_auth) == []
  end

  test "basic auth returns authorization header with base64 credentials" do
    headers = Auth.to_headers({:basic, "user@example.com", "secret123"})

    assert [{"authorization", auth_value}] = headers
    assert auth_value =~ "Basic "

    # Verify the base64 encoding
    encoded = String.replace(auth_value, "Basic ", "")
    decoded = Base.decode64!(encoded)
    assert decoded == "user@example.com:secret123"
  end

  test "bearer auth returns authorization header with token" do
    token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test"
    headers = Auth.to_headers({:bearer, token})

    assert [{"authorization", auth_value}] = headers
    assert auth_value == "Bearer #{token}"
  end
end
