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

    assert {:ok, _} =
             CalDAVEx.create_event(client, base_url <> "/calendars/test/", "event.ics", ics_data)
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

    assert {:ok, _} =
             CalDAVEx.update_event(client, base_url <> "/calendars/test/event.ics", ics_data)
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

    assert {:ok, _} =
             CalDAVEx.update_event(
               client,
               base_url <> "/calendars/test/event.ics",
               ics_data,
               "\"etag-123\""
             )
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

    assert {:ok, _} =
             CalDAVEx.delete_event(
               client,
               base_url <> "/calendars/test/event.ics",
               "\"etag-456\""
             )
  end

  test "discover calls Discovery.discover" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"

    Bypass.expect(bypass, fn conn ->
      case conn.request_path do
        "/" ->
          conn
          |> Plug.Conn.put_resp_content_type("application/xml")
          |> Plug.Conn.resp(207, """
          <?xml version="1.0" encoding="UTF-8"?>
          <D:multistatus xmlns:D="DAV:">
            <D:response>
              <D:href>/</D:href>
              <D:propstat>
                <D:prop>
                  <D:current-user-principal>
                    <D:href>/principals/user/</D:href>
                  </D:current-user-principal>
                </D:prop>
                <D:status>HTTP/1.1 200 OK</D:status>
              </D:propstat>
            </D:response>
          </D:multistatus>
          """)

        "/principals/user/" ->
          conn
          |> Plug.Conn.put_resp_content_type("application/xml")
          |> Plug.Conn.resp(207, """
          <?xml version="1.0" encoding="UTF-8"?>
          <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
            <D:response>
              <D:href>/principals/user/</D:href>
              <D:propstat>
                <D:prop>
                  <C:calendar-home-set>
                    <D:href>/calendars/user/</D:href>
                  </C:calendar-home-set>
                </D:prop>
                <D:status>HTTP/1.1 200 OK</D:status>
              </D:propstat>
            </D:response>
          </D:multistatus>
          """)
      end
    end)

    client =
      base_url
      |> CalDAVEx.new_config(CalDAVEx.no_auth())
      |> CalDAVEx.new_client()

    assert {:ok, discovery_info} = CalDAVEx.discover(client)
    assert discovery_info.principal_url == base_url <> "/principals/user/"
    assert discovery_info.calendar_home_set_url == base_url <> "/calendars/user/"
  end

  test "list_calendars calls Calendar.list" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"

    Bypass.expect_once(bypass, fn conn ->
      assert "PROPFIND" == conn.method
      assert "/calendars/user/" == conn.request_path

      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, """
      <?xml version="1.0" encoding="UTF-8"?>
      <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
        <D:response>
          <D:href>/calendars/user/work/</D:href>
          <D:propstat>
            <D:prop>
              <D:displayname>Work</D:displayname>
              <D:resourcetype><D:collection/><C:calendar/></D:resourcetype>
            </D:prop>
            <D:status>HTTP/1.1 200 OK</D:status>
          </D:propstat>
        </D:response>
      </D:multistatus>
      """)
    end)

    client =
      base_url
      |> CalDAVEx.new_config(CalDAVEx.no_auth())
      |> CalDAVEx.new_client()

    discovery_info = %CalDAVEx.Types.DiscoveryInfo{
      principal_url: base_url <> "/principals/user/",
      calendar_home_set_url: base_url <> "/calendars/user/"
    }

    assert {:ok, [calendar]} = CalDAVEx.list_calendars(client, discovery_info)
    assert calendar.display_name == "Work"
  end

  test "list_events calls Event.list" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"

    Bypass.expect_once(bypass, fn conn ->
      assert "REPORT" == conn.method

      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, """
      <?xml version="1.0" encoding="UTF-8"?>
      <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
        <D:response>
          <D:href>/calendars/user/work/event.ics</D:href>
          <D:propstat>
            <D:prop>
              <D:getetag>&quot;e1&quot;</D:getetag>
              <C:calendar-data>BEGIN:VCALENDAR&#10;VERSION:2.0&#10;BEGIN:VEVENT&#10;UID:e1&#10;SUMMARY:Meeting&#10;DTSTART:20250520T140000Z&#10;DTEND:20250520T150000Z&#10;END:VEVENT&#10;END:VCALENDAR</C:calendar-data>
            </D:prop>
            <D:status>HTTP/1.1 200 OK</D:status>
          </D:propstat>
        </D:response>
      </D:multistatus>
      """)
    end)

    client =
      base_url
      |> CalDAVEx.new_config(CalDAVEx.no_auth())
      |> CalDAVEx.new_client()

    assert {:ok, [event]} = CalDAVEx.list_events(client, base_url <> "/calendars/user/work/")
    assert event.summary == "Meeting"
  end

  test "get_event calls Event.get" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"

    Bypass.expect_once(bypass, fn conn ->
      assert "GET" == conn.method

      conn
      |> Plug.Conn.put_resp_header("etag", "\"e1\"")
      |> Plug.Conn.put_resp_content_type("text/calendar")
      |> Plug.Conn.resp(200, "BEGIN:VCALENDAR\nVERSION:2.0\nEND:VCALENDAR")
    end)

    client =
      base_url
      |> CalDAVEx.new_config(CalDAVEx.no_auth())
      |> CalDAVEx.new_client()

    assert {:ok, event} = CalDAVEx.get_event(client, base_url <> "/calendars/user/work/event.ics")
    assert event.etag == "\"e1\""
  end
end
