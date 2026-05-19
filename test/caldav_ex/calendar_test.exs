defmodule CalDAVEx.CalendarTest do
  use ExUnit.Case, async: true

  alias CalDAVEx.Types.{Calendar, DiscoveryInfo}

  test "lists calendars from the discovered calendar home set" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"

    Bypass.expect_once(bypass, fn conn ->
      assert "PROPFIND" == conn.method
      assert "/calendars/user/" == conn.request_path
      assert ["1"] = Plug.Conn.get_req_header(conn, "depth")
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert body =~ "<D:propfind"
      assert body =~ "<D:displayname/>"
      assert body =~ "calendar-description"
      assert body =~ "getctag"

      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, """
      <?xml version="1.0" encoding="UTF-8"?>
      <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:CS="http://calendarserver.org/ns/">
        <D:response>
          <D:href>/calendars/user/personal/</D:href>
          <D:propstat>
            <D:prop>
              <D:displayname>Personal</D:displayname>
              <C:calendar-description>Personal calendar</C:calendar-description>
              <CS:getctag>abc123</CS:getctag>
            </D:prop>
            <D:status>HTTP/1.1 200 OK</D:status>
          </D:propstat>
        </D:response>
        <D:response>
          <D:href>/calendars/user/work/</D:href>
          <D:propstat>
            <D:prop>
              <D:displayname>Work</D:displayname>
              <C:calendar-description>Work calendar</C:calendar-description>
              <CS:getctag>def456</CS:getctag>
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

    discovery_info = %DiscoveryInfo{
      principal_url: base_url <> "/principals/user/",
      calendar_home_set_url: base_url <> "/calendars/user/"
    }

    assert {:ok, calendars} = CalDAVEx.Calendar.list(client, discovery_info)

    assert calendars == [
             %Calendar{
               url: base_url <> "/calendars/user/personal/",
               display_name: "Personal",
               description: "Personal calendar",
               ctag: "abc123"
             },
             %Calendar{
               url: base_url <> "/calendars/user/work/",
               display_name: "Work",
               description: "Work calendar",
               ctag: "def456"
             }
           ]
  end
end
