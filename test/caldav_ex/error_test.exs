defmodule CalDAVEx.ErrorTest do
  use ExUnit.Case, async: true

  alias CalDAVEx.Error

  test "creates transport error" do
    error = Error.transport("Connection refused")
    assert error.type == :transport
    assert error.message == "Connection refused"
  end

  test "creates HTTP error with status and body" do
    error = Error.http(404, "Resource not found")
    assert error.type == :http
    assert error.message == "HTTP 404"
    assert error.details == "Resource not found"
  end

  test "creates XML parsing error" do
    error = Error.xml("Invalid XML syntax")
    assert error.type == :xml
    assert error.message == "Invalid XML syntax"
  end

  test "creates protocol error" do
    error = Error.protocol("Missing required property")
    assert error.type == :protocol
    assert error.message == "Missing required property"
  end

  test "creates not found error" do
    error = Error.not_found()
    assert error.type == :not_found
  end

  test "creates unauthorized error" do
    error = Error.unauthorized()
    assert error.type == :unauthorized
  end

  test "creates conflict error" do
    error = Error.conflict()
    assert error.type == :conflict
  end

  test "converts transport error to string" do
    error = Error.transport("Network timeout")
    assert Error.to_string(error) == "[caldav_ex] Transport error: Network timeout"
  end

  test "converts HTTP error to string" do
    error = Error.http(500, "Internal server error")
    assert Error.to_string(error) == "[caldav_ex] HTTP error: HTTP 500 - Internal server error"
  end

  test "converts XML error to string" do
    error = Error.xml("Parse failed")
    assert Error.to_string(error) == "[caldav_ex] XML error: Parse failed"
  end

  test "converts protocol error to string" do
    error = Error.protocol("Invalid response")
    assert Error.to_string(error) == "[caldav_ex] Protocol error: Invalid response"
  end

  test "converts not found error to string" do
    error = Error.not_found()
    assert Error.to_string(error) == "[caldav_ex] Not found"
  end

  test "converts unauthorized error to string" do
    error = Error.unauthorized()
    assert Error.to_string(error) == "[caldav_ex] Unauthorized"
  end

  test "converts conflict error to string" do
    error = Error.conflict()
    assert Error.to_string(error) == "[caldav_ex] Conflict"
  end

  test "converts unknown error type to string" do
    error = %Error{type: :unknown, message: "Something went wrong"}
    assert Error.to_string(error) == "[caldav_ex] Unknown error"
  end
end
