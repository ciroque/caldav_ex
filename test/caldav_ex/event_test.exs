defmodule CalDAVEx.EventTest do
  use ExUnit.Case, async: true

  alias CalDAVEx.Types.Event

  test "lists events in a time range from a calendar" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    calendar_url = base_url <> "/calendars/user/personal/"

    Bypass.expect_once(bypass, fn conn ->
      assert "REPORT" == conn.method
      assert "/calendars/user/personal/" == conn.request_path
      assert ["1"] = Plug.Conn.get_req_header(conn, "depth")
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert body =~ "<C:calendar-query"
      assert body =~ "start=\"20250501T000000Z\""
      assert body =~ "end=\"20250531T235959Z\""

      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, """
      <?xml version="1.0" encoding="UTF-8"?>
      <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
        <D:response>
          <D:href>/calendars/user/personal/meeting.ics</D:href>
          <D:propstat>
            <D:prop>
              <D:getetag>&quot;etag-1&quot;</D:getetag>
              <C:calendar-data>BEGIN:VCALENDAR&#10;VERSION:2.0&#10;BEGIN:VEVENT&#10;UID:meeting-1&#10;SUMMARY:Planning Meeting&#10;DTSTART:20250515T140000Z&#10;DTEND:20250515T150000Z&#10;END:VEVENT&#10;END:VCALENDAR</C:calendar-data>
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

    assert {:ok, events} =
             CalDAVEx.Event.list(client, calendar_url,
               from: ~U[2025-05-01 00:00:00Z],
               to: ~U[2025-05-31 23:59:59Z]
             )

    assert [event] = events

    event_url = calendar_url <> "meeting.ics"

    assert %Event{
             href: ^event_url,
             etag: "\"etag-1\"",
             calendar_data: calendar_data,
             summary: "Planning Meeting",
             dtstart: ~U[2025-05-15 14:00:00Z],
             dtend: ~U[2025-05-15 15:00:00Z]
           } = event

    assert calendar_data =~ "BEGIN:VCALENDAR"
  end
end
