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

  test "gets a single event by URL" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    event_url = base_url <> "/calendars/user/personal/meeting.ics"

    Bypass.expect_once(bypass, fn conn ->
      assert "GET" == conn.method
      assert "/calendars/user/personal/meeting.ics" == conn.request_path

      conn
      |> Plug.Conn.put_resp_header("etag", "\"abc-123\"")
      |> Plug.Conn.put_resp_content_type("text/calendar")
      |> Plug.Conn.resp(200, """
      BEGIN:VCALENDAR
      VERSION:2.0
      PRODID:-//Example Corp//CalDAV Client//EN
      BEGIN:VEVENT
      UID:meeting-1@example.com
      SUMMARY:Team Standup
      DTSTART:20250520T090000Z
      DTEND:20250520T093000Z
      LOCATION:Conference Room A
      DESCRIPTION:Daily team sync
      END:VEVENT
      END:VCALENDAR
      """)
    end)

    client =
      base_url
      |> CalDAVEx.new_config(CalDAVEx.no_auth())
      |> CalDAVEx.new_client()

    assert {:ok, event} = CalDAVEx.Event.get(client, event_url)

    assert %Event{
             href: ^event_url,
             etag: "\"abc-123\"",
             calendar_data: calendar_data
           } = event

    assert calendar_data =~ "BEGIN:VCALENDAR"
    assert calendar_data =~ "SUMMARY:Team Standup"
    assert calendar_data =~ "UID:meeting-1@example.com"
  end
end
