defmodule CalDAVEx.DiscoveryTest do
  use ExUnit.Case, async: true

  alias CalDAVEx.Types.DiscoveryInfo

  test "discovers principal and calendar home set from PROPFIND responses" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"

    Bypass.expect(bypass, fn conn ->
      assert "PROPFIND" == conn.method
      assert ["0"] = Plug.Conn.get_req_header(conn, "depth")
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      case conn.request_path do
        "/" ->
          assert body =~ "current-user-principal"

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
                    <D:href>/principals/users/alice/</D:href>
                  </D:current-user-principal>
                </D:prop>
                <D:status>HTTP/1.1 200 OK</D:status>
              </D:propstat>
            </D:response>
          </D:multistatus>
          """)

        "/principals/users/alice/" ->
          assert body =~ "calendar-home-set"

          conn
          |> Plug.Conn.put_resp_content_type("application/xml")
          |> Plug.Conn.resp(207, """
          <?xml version="1.0" encoding="UTF-8"?>
          <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
            <D:response>
              <D:href>/principals/users/alice/</D:href>
              <D:propstat>
                <D:prop>
                  <C:calendar-home-set>
                    <D:href>/calendars/alice/</D:href>
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

    assert {:ok,
            %DiscoveryInfo{
              principal_url: principal_url,
              calendar_home_set_url: calendar_home_set_url
            }} = CalDAVEx.discover(client)

    assert principal_url == base_url <> "/principals/users/alice/"
    assert calendar_home_set_url == base_url <> "/calendars/alice/"
  end

  test "handles absolute URLs in discovery responses" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    absolute_principal = "http://localhost:#{bypass.port}/principals/user/"
    absolute_calendar = "http://localhost:#{bypass.port}/calendars/user/"

    Bypass.expect(bypass, fn conn ->
      assert "PROPFIND" == conn.method

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
                    <D:href>#{absolute_principal}</D:href>
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
                    <D:href>#{absolute_calendar}</D:href>
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

    assert {:ok,
            %DiscoveryInfo{
              principal_url: ^absolute_principal,
              calendar_home_set_url: ^absolute_calendar
            }} = CalDAVEx.discover(client)
  end

  test "handles CDATA in discovery responses" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"

    Bypass.expect(bypass, fn conn ->
      assert "PROPFIND" == conn.method

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
                    <D:href><![CDATA[/principals/users/alice/]]></D:href>
                  </D:current-user-principal>
                </D:prop>
                <D:status>HTTP/1.1 200 OK</D:status>
              </D:propstat>
            </D:response>
          </D:multistatus>
          """)

        "/principals/users/alice/" ->
          conn
          |> Plug.Conn.put_resp_content_type("application/xml")
          |> Plug.Conn.resp(207, """
          <?xml version="1.0" encoding="UTF-8"?>
          <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
            <D:response>
              <D:href>/principals/users/alice/</D:href>
              <D:propstat>
                <D:prop>
                  <C:calendar-home-set>
                    <D:href><![CDATA[/calendars/alice/]]></D:href>
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

    assert {:ok,
            %DiscoveryInfo{
              principal_url: principal_url,
              calendar_home_set_url: calendar_home_set_url
            }} = CalDAVEx.discover(client)

    assert principal_url == base_url <> "/principals/users/alice/"
    assert calendar_home_set_url == base_url <> "/calendars/alice/"
  end

  test "handles whitespace-only href" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"

    Bypass.expect_once(bypass, fn conn ->
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
                <D:href>   </D:href>
              </D:current-user-principal>
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

    assert {:error, error} = CalDAVEx.discover(client)
    assert error.type == :protocol
  end
end
