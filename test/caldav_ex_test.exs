defmodule CalDAVExTest do
  use ExUnit.Case, async: true

  test "no_auth returns :no_auth" do
    assert CalDAVEx.no_auth() == :no_auth
  end

  test "basic_auth returns basic auth tuple" do
    assert CalDAVEx.basic_auth("user", "pass") == {:basic, "user", "pass"}
  end

  test "bearer_auth returns bearer auth tuple" do
    assert CalDAVEx.bearer_auth("token123") == {:bearer, "token123"}
  end

  test "new_config creates config" do
    config = CalDAVEx.new_config("https://caldav.example.com", CalDAVEx.no_auth())

    assert config.base_url == "https://caldav.example.com"
    assert config.auth == :no_auth
  end

  test "with_user_agent updates config" do
    config =
      CalDAVEx.new_config("https://caldav.example.com", CalDAVEx.no_auth())
      |> CalDAVEx.with_user_agent("TestApp/1.0")

    assert config.user_agent == "TestApp/1.0"
  end

  test "with_timeout updates config" do
    config =
      CalDAVEx.new_config("https://caldav.example.com", CalDAVEx.no_auth())
      |> CalDAVEx.with_timeout(20_000)

    assert config.timeout_ms == 20_000
  end

  test "new_client creates client" do
    config = CalDAVEx.new_config("https://caldav.example.com", CalDAVEx.no_auth())
    client = CalDAVEx.new_client(config)

    assert client.config == config
  end

  test "error_to_string converts error" do
    error = CalDAVEx.Error.http(404, "Not found")
    string = CalDAVEx.error_to_string(error)

    assert string == "[caldav_ex] HTTP error: HTTP 404 - Not found"
  end

  test "create_event calls Event.create" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"

    Bypass.expect_once(bypass, fn conn ->
      assert "PUT" == conn.method
      assert "/calendars/test/event.ics" == conn.request_path

      conn
      |> Plug.Conn.resp(201, "")
    end)

    client =
      base_url
      |> CalDAVEx.new_config(CalDAVEx.no_auth())
      |> CalDAVEx.new_client()

    ics_data = "BEGIN:VCALENDAR\nVERSION:2.0\nEND:VCALENDAR"
    assert {:ok, _} = CalDAVEx.create_event(client, base_url <> "/calendars/test/", "event.ics", ics_data)
  end

  test "update_event calls Event.update" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"

    Bypass.expect_once(bypass, fn conn ->
      assert "PUT" == conn.method
      assert "/calendars/test/event.ics" == conn.request_path

      conn
      |> Plug.Conn.resp(204, "")
    end)

    client =
      base_url
      |> CalDAVEx.new_config(CalDAVEx.no_auth())
      |> CalDAVEx.new_client()

    ics_data = "BEGIN:VCALENDAR\nVERSION:2.0\nEND:VCALENDAR"
    assert {:ok, _} = CalDAVEx.update_event(client, base_url <> "/calendars/test/event.ics", ics_data)
  end

  test "update_event with etag calls Event.update with etag" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"

    Bypass.expect_once(bypass, fn conn ->
      assert "PUT" == conn.method
      assert ["\"etag-123\""] = Plug.Conn.get_req_header(conn, "if-match")

      conn
      |> Plug.Conn.resp(204, "")
    end)

    client =
      base_url
      |> CalDAVEx.new_config(CalDAVEx.no_auth())
      |> CalDAVEx.new_client()

    ics_data = "BEGIN:VCALENDAR\nVERSION:2.0\nEND:VCALENDAR"
    assert {:ok, _} = CalDAVEx.update_event(client, base_url <> "/calendars/test/event.ics", ics_data, "\"etag-123\"")
  end

  test "delete_event calls Event.delete" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"

    Bypass.expect_once(bypass, fn conn ->
      assert "DELETE" == conn.method
      assert "/calendars/test/event.ics" == conn.request_path

      conn
      |> Plug.Conn.resp(204, "")
    end)

    client =
      base_url
      |> CalDAVEx.new_config(CalDAVEx.no_auth())
      |> CalDAVEx.new_client()

    assert {:ok, _} = CalDAVEx.delete_event(client, base_url <> "/calendars/test/event.ics")
  end

  test "delete_event with etag calls Event.delete with etag" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"

    Bypass.expect_once(bypass, fn conn ->
      assert "DELETE" == conn.method
      assert ["\"etag-456\""] = Plug.Conn.get_req_header(conn, "if-match")

      conn
      |> Plug.Conn.resp(204, "")
    end)

    client =
      base_url
      |> CalDAVEx.new_config(CalDAVEx.no_auth())
      |> CalDAVEx.new_client()

    assert {:ok, _} = CalDAVEx.delete_event(client, base_url <> "/calendars/test/event.ics", "\"etag-456\"")
  end
end
