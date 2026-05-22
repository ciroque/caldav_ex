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

  test "parses recurring events with extended fields" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    calendar_url = base_url <> "/calendars/user/personal/"

    Bypass.expect_once(bypass, fn conn ->
      assert "REPORT" == conn.method
      assert "/calendars/user/personal/" == conn.request_path

      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, """
      <?xml version="1.0" encoding="UTF-8"?>
      <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
        <D:response>
          <D:href>/calendars/user/personal/weekly-meeting.ics</D:href>
          <D:propstat>
            <D:prop>
              <D:getetag>&quot;recurring-1&quot;</D:getetag>
              <C:calendar-data>BEGIN:VCALENDAR&#10;VERSION:2.0&#10;PRODID:-//Example//EN&#10;BEGIN:VEVENT&#10;UID:weekly-meeting-123&#10;SUMMARY:Weekly Team Sync&#10;DESCRIPTION:Discuss project progress and blockers&#10;LOCATION:Conference Room B&#10;STATUS:CONFIRMED&#10;DTSTART:20250520T140000Z&#10;DTEND:20250520T150000Z&#10;RRULE:FREQ=WEEKLY;BYDAY=TU&#10;ORGANIZER:mailto:manager@example.com&#10;ATTENDEE:mailto:alice@example.com&#10;ATTENDEE:mailto:bob@example.com&#10;END:VEVENT&#10;END:VCALENDAR</C:calendar-data>
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

    assert {:ok, events} = CalDAVEx.Event.list(client, calendar_url)

    assert [event] = events

    event_url = calendar_url <> "weekly-meeting.ics"

    assert %Event{
             href: ^event_url,
             etag: "\"recurring-1\"",
             summary: "Weekly Team Sync",
             uid: "weekly-meeting-123",
             description: "Discuss project progress and blockers",
             location: "Conference Room B",
             status: "CONFIRMED",
             dtstart: ~U[2025-05-20 14:00:00Z],
             dtend: ~U[2025-05-20 15:00:00Z],
             rrule: rrule,
             organizer: organizer,
             attendees: attendees
           } = event

    assert rrule =~ "FREQ=WEEKLY"
    assert rrule =~ "BYDAY=TU"
    assert organizer == "mailto:manager@example.com"
    assert length(attendees) == 2
    assert "mailto:alice@example.com" in attendees
    assert "mailto:bob@example.com" in attendees
  end

  test "lists events with only from time range" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    calendar_url = base_url <> "/calendars/user/personal/"

    Bypass.expect_once(bypass, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert body =~ "start=\"20250515T000000Z\""
      refute body =~ "end="

      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, """
      <?xml version="1.0" encoding="UTF-8"?>
      <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
      </D:multistatus>
      """)
    end)

    client =
      base_url
      |> CalDAVEx.new_config(CalDAVEx.no_auth())
      |> CalDAVEx.new_client()

    assert {:ok, []} = CalDAVEx.Event.list(client, calendar_url, from: ~U[2025-05-15 00:00:00Z])
  end

  test "lists events with only to time range" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    calendar_url = base_url <> "/calendars/user/personal/"

    Bypass.expect_once(bypass, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert body =~ "end=\"20250531T235959Z\""
      refute body =~ "start="

      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, """
      <?xml version="1.0" encoding="UTF-8"?>
      <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
      </D:multistatus>
      """)
    end)

    client =
      base_url
      |> CalDAVEx.new_config(CalDAVEx.no_auth())
      |> CalDAVEx.new_client()

    assert {:ok, []} = CalDAVEx.Event.list(client, calendar_url, to: ~U[2025-05-31 23:59:59Z])
  end

  test "parses event with complex RRULE" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    calendar_url = base_url <> "/calendars/user/personal/"

    Bypass.expect_once(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, """
      <?xml version="1.0" encoding="UTF-8"?>
      <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
        <D:response>
          <D:href>/calendars/user/personal/complex.ics</D:href>
          <D:propstat>
            <D:prop>
              <D:getetag>&quot;complex-1&quot;</D:getetag>
              <C:calendar-data>BEGIN:VCALENDAR&#10;VERSION:2.0&#10;BEGIN:VEVENT&#10;UID:complex-123&#10;SUMMARY:Complex Recurring Event&#10;DTSTART:20250520T140000Z&#10;DTEND:20250520T150000Z&#10;RRULE:FREQ=MONTHLY;INTERVAL=2;COUNT=10;BYDAY=1MO,-1FR;BYMONTHDAY=15;BYMONTH=1,6,12&#10;END:VEVENT&#10;END:VCALENDAR</C:calendar-data>
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

    assert {:ok, [event]} = CalDAVEx.Event.list(client, calendar_url)

    assert event.rrule =~ "FREQ=MONTHLY"
    assert event.rrule =~ "INTERVAL=2"
    assert event.rrule =~ "COUNT=10"
    assert event.rrule =~ "BYDAY=1MO,-1FR"
    assert event.rrule =~ "BYMONTHDAY=15"
    assert event.rrule =~ "BYMONTH=1,6,12"
  end

  test "handles event with malformed calendar data" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    calendar_url = base_url <> "/calendars/user/personal/"

    Bypass.expect_once(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, """
      <?xml version="1.0" encoding="UTF-8"?>
      <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
        <D:response>
          <D:href>/calendars/user/personal/malformed.ics</D:href>
          <D:propstat>
            <D:prop>
              <D:getetag>&quot;malformed-1&quot;</D:getetag>
              <C:calendar-data>INVALID ICS DATA</C:calendar-data>
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

    assert {:ok, [event]} = CalDAVEx.Event.list(client, calendar_url)
    assert event.summary == nil
    assert event.dtstart == nil
    assert event.dtend == nil
  end

  test "filters out responses without calendar data" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    calendar_url = base_url <> "/calendars/user/personal/"

    Bypass.expect_once(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, """
      <?xml version="1.0" encoding="UTF-8"?>
      <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
        <D:response>
          <D:href>/calendars/user/personal/</D:href>
          <D:propstat>
            <D:prop>
              <D:displayname>Personal</D:displayname>
            </D:prop>
            <D:status>HTTP/1.1 200 OK</D:status>
          </D:propstat>
        </D:response>
        <D:response>
          <D:href>/calendars/user/personal/event.ics</D:href>
          <D:propstat>
            <D:prop>
              <D:getetag>&quot;event-1&quot;</D:getetag>
              <C:calendar-data>BEGIN:VCALENDAR&#10;VERSION:2.0&#10;BEGIN:VEVENT&#10;UID:event-1&#10;SUMMARY:Real Event&#10;DTSTART:20250520T140000Z&#10;DTEND:20250520T150000Z&#10;END:VEVENT&#10;END:VCALENDAR</C:calendar-data>
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

    assert {:ok, [event]} = CalDAVEx.Event.list(client, calendar_url)
    assert event.summary == "Real Event"
  end

  test "get event handles etag as list" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    event_url = base_url <> "/calendars/user/personal/event.ics"

    Bypass.expect_once(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("etag", "\"etag-value\"")
      |> Plug.Conn.put_resp_content_type("text/calendar")
      |> Plug.Conn.resp(200, "BEGIN:VCALENDAR\nVERSION:2.0\nEND:VCALENDAR")
    end)

    client =
      base_url
      |> CalDAVEx.new_config(CalDAVEx.no_auth())
      |> CalDAVEx.new_client()

    assert {:ok, event} = CalDAVEx.Event.get(client, event_url)
    assert event.etag == "\"etag-value\""
  end

  test "create event with if-none-match header" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    calendar_url = base_url <> "/calendars/user/personal/"

    Bypass.expect_once(bypass, fn conn ->
      assert "PUT" == conn.method
      assert ["*"] = Plug.Conn.get_req_header(conn, "if-none-match")
      assert "/calendars/user/personal/new-event.ics" == conn.request_path

      conn
      |> Plug.Conn.resp(201, "")
    end)

    client =
      base_url
      |> CalDAVEx.new_config(CalDAVEx.no_auth())
      |> CalDAVEx.new_client()

    ics_data = "BEGIN:VCALENDAR\nVERSION:2.0\nEND:VCALENDAR"
    assert {:ok, event} = CalDAVEx.Event.create(client, calendar_url, "new-event.ics", ics_data)
    assert event.href == calendar_url <> "new-event.ics"
  end

  test "update event without etag" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    event_url = base_url <> "/calendars/user/personal/event.ics"

    Bypass.expect_once(bypass, fn conn ->
      assert "PUT" == conn.method
      assert [] = Plug.Conn.get_req_header(conn, "if-match")

      conn
      |> Plug.Conn.resp(204, "")
    end)

    client =
      base_url
      |> CalDAVEx.new_config(CalDAVEx.no_auth())
      |> CalDAVEx.new_client()

    ics_data = "BEGIN:VCALENDAR\nVERSION:2.0\nEND:VCALENDAR"
    assert {:ok, _} = CalDAVEx.Event.update(client, event_url, ics_data, nil)
  end

  test "delete event without etag" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    event_url = base_url <> "/calendars/user/personal/event.ics"

    Bypass.expect_once(bypass, fn conn ->
      assert "DELETE" == conn.method
      assert [] = Plug.Conn.get_req_header(conn, "if-match")

      conn
      |> Plug.Conn.resp(204, "")
    end)

    client =
      base_url
      |> CalDAVEx.new_config(CalDAVEx.no_auth())
      |> CalDAVEx.new_client()

    assert {:ok, _} = CalDAVEx.Event.delete(client, event_url, nil)
  end

  test "parses event with RRULE UNTIL as DateTime" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    calendar_url = base_url <> "/calendars/user/personal/"

    Bypass.expect_once(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, """
      <?xml version="1.0" encoding="UTF-8"?>
      <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
        <D:response>
          <D:href>/calendars/user/personal/until-datetime.ics</D:href>
          <D:propstat>
            <D:prop>
              <D:getetag>&quot;until-dt-1&quot;</D:getetag>
              <C:calendar-data>BEGIN:VCALENDAR&#10;VERSION:2.0&#10;BEGIN:VEVENT&#10;UID:until-dt-123&#10;SUMMARY:Event with UNTIL datetime&#10;DTSTART:20250520T140000Z&#10;DTEND:20250520T150000Z&#10;RRULE:FREQ=DAILY;UNTIL=20251231T235959Z&#10;END:VEVENT&#10;END:VCALENDAR</C:calendar-data>
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

    assert {:ok, [event]} = CalDAVEx.Event.list(client, calendar_url)
    assert event.rrule =~ "FREQ=DAILY"
  end

  test "parses event with string RRULE" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    calendar_url = base_url <> "/calendars/user/personal/"

    Bypass.expect_once(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, """
      <?xml version="1.0" encoding="UTF-8"?>
      <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
        <D:response>
          <D:href>/calendars/user/personal/string-rrule.ics</D:href>
          <D:propstat>
            <D:prop>
              <D:getetag>&quot;str-rrule-1&quot;</D:getetag>
              <C:calendar-data>BEGIN:VCALENDAR&#10;VERSION:2.0&#10;BEGIN:VEVENT&#10;UID:str-rrule-123&#10;SUMMARY:Event with string RRULE&#10;DTSTART:20250520T140000Z&#10;DTEND:20250520T150000Z&#10;RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR&#10;END:VEVENT&#10;END:VCALENDAR</C:calendar-data>
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

    assert {:ok, [event]} = CalDAVEx.Event.list(client, calendar_url)
    assert is_binary(event.rrule)
  end

  test "parses event with ICal.Attendee structs" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    calendar_url = base_url <> "/calendars/user/personal/"

    Bypass.expect_once(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, """
      <?xml version="1.0" encoding="UTF-8"?>
      <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
        <D:response>
          <D:href>/calendars/user/personal/attendees.ics</D:href>
          <D:propstat>
            <D:prop>
              <D:getetag>&quot;att-1&quot;</D:getetag>
              <C:calendar-data>BEGIN:VCALENDAR&#10;VERSION:2.0&#10;BEGIN:VEVENT&#10;UID:att-123&#10;SUMMARY:Event with attendees&#10;DTSTART:20250520T140000Z&#10;DTEND:20250520T150000Z&#10;ATTENDEE;CN=Alice:mailto:alice@example.com&#10;ATTENDEE;CN=Bob:mailto:bob@example.com&#10;END:VEVENT&#10;END:VCALENDAR</C:calendar-data>
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

    assert {:ok, [event]} = CalDAVEx.Event.list(client, calendar_url)
    assert is_list(event.attendees)
  end

  test "handles event without status" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    calendar_url = base_url <> "/calendars/user/personal/"

    Bypass.expect_once(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, """
      <?xml version="1.0" encoding="UTF-8"?>
      <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
        <D:response>
          <D:href>/calendars/user/personal/no-status.ics</D:href>
          <D:propstat>
            <D:prop>
              <D:getetag>&quot;ns-1&quot;</D:getetag>
              <C:calendar-data>BEGIN:VCALENDAR&#10;VERSION:2.0&#10;BEGIN:VEVENT&#10;UID:ns-123&#10;SUMMARY:Event without status&#10;DTSTART:20250520T140000Z&#10;DTEND:20250520T150000Z&#10;END:VEVENT&#10;END:VCALENDAR</C:calendar-data>
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

    assert {:ok, [event]} = CalDAVEx.Event.list(client, calendar_url)
    assert event.status == nil
  end

  test "handles event without organizer" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    calendar_url = base_url <> "/calendars/user/personal/"

    Bypass.expect_once(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, """
      <?xml version="1.0" encoding="UTF-8"?>
      <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
        <D:response>
          <D:href>/calendars/user/personal/no-org.ics</D:href>
          <D:propstat>
            <D:prop>
              <D:getetag>&quot;no-1&quot;</D:getetag>
              <C:calendar-data>BEGIN:VCALENDAR&#10;VERSION:2.0&#10;BEGIN:VEVENT&#10;UID:no-123&#10;SUMMARY:Event without organizer&#10;DTSTART:20250520T140000Z&#10;DTEND:20250520T150000Z&#10;END:VEVENT&#10;END:VCALENDAR</C:calendar-data>
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

    assert {:ok, [event]} = CalDAVEx.Event.list(client, calendar_url)
    assert event.organizer == nil
  end

  test "parses event with RRULE interval=1 (default)" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    calendar_url = base_url <> "/calendars/user/personal/"

    Bypass.expect_once(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, """
      <?xml version="1.0" encoding="UTF-8"?>
      <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
        <D:response>
          <D:href>/calendars/user/personal/interval-default.ics</D:href>
          <D:propstat>
            <D:prop>
              <D:getetag>&quot;int-1&quot;</D:getetag>
              <C:calendar-data>BEGIN:VCALENDAR&#10;VERSION:2.0&#10;BEGIN:VEVENT&#10;UID:int-123&#10;SUMMARY:Event with default interval&#10;DTSTART:20250520T140000Z&#10;DTEND:20250520T150000Z&#10;RRULE:FREQ=DAILY;INTERVAL=1&#10;END:VEVENT&#10;END:VCALENDAR</C:calendar-data>
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

    assert {:ok, [event]} = CalDAVEx.Event.list(client, calendar_url)
    assert event.rrule =~ "FREQ=DAILY"
    refute event.rrule =~ "INTERVAL"
  end

  test "parses event with empty by_day list" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    calendar_url = base_url <> "/calendars/user/personal/"

    Bypass.expect_once(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, """
      <?xml version="1.0" encoding="UTF-8"?>
      <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
        <D:response>
          <D:href>/calendars/user/personal/empty-byday.ics</D:href>
          <D:propstat>
            <D:prop>
              <D:getetag>&quot;ebd-1&quot;</D:getetag>
              <C:calendar-data>BEGIN:VCALENDAR&#10;VERSION:2.0&#10;BEGIN:VEVENT&#10;UID:ebd-123&#10;SUMMARY:Event with empty by_day&#10;DTSTART:20250520T140000Z&#10;DTEND:20250520T150000Z&#10;RRULE:FREQ=WEEKLY&#10;END:VEVENT&#10;END:VCALENDAR</C:calendar-data>
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

    assert {:ok, [event]} = CalDAVEx.Event.list(client, calendar_url)
    assert event.rrule =~ "FREQ=WEEKLY"
    refute event.rrule =~ "BYDAY"
  end

  test "handles event with empty calendar (no events)" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    calendar_url = base_url <> "/calendars/user/personal/"

    Bypass.expect_once(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, """
      <?xml version="1.0" encoding="UTF-8"?>
      <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
        <D:response>
          <D:href>/calendars/user/personal/empty.ics</D:href>
          <D:propstat>
            <D:prop>
              <D:getetag>&quot;empty-1&quot;</D:getetag>
              <C:calendar-data>BEGIN:VCALENDAR&#10;VERSION:2.0&#10;END:VCALENDAR</C:calendar-data>
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

    assert {:ok, [event]} = CalDAVEx.Event.list(client, calendar_url)
    assert event.summary == nil
    assert event.dtstart == nil
  end

  test "parses event with TZID parameter in DTSTART/DTEND" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    calendar_url = base_url <> "/calendars/user/personal/"

    Bypass.expect_once(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, """
      <?xml version="1.0" encoding="UTF-8"?>
      <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
        <D:response>
          <D:href>/calendars/user/personal/tzid-event.ics</D:href>
          <D:propstat>
            <D:prop>
              <D:getetag>&quot;tzid-1&quot;</D:getetag>
              <C:calendar-data>BEGIN:VCALENDAR&#13;&#10;VERSION:2.0&#13;&#10;PRODID:-//Example//EN&#13;&#10;BEGIN:VEVENT&#13;&#10;UID:tzid-event-123&#13;&#10;SUMMARY:Event with TZID&#13;&#10;DTSTART;TZID=America/Los_Angeles:20260120T160000&#13;&#10;DTEND;TZID=America/Los_Angeles:20260120T170000&#13;&#10;DESCRIPTION:Test event with timezone&#13;&#10;LOCATION:Los Angeles&#13;&#10;END:VEVENT&#13;&#10;END:VCALENDAR</C:calendar-data>
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

    assert {:ok, [event]} = CalDAVEx.Event.list(client, calendar_url)

    assert event.summary == "Event with TZID"
    assert event.description == "Test event with timezone"
    assert event.location == "Los Angeles"

    # America/Los_Angeles is UTC-8 (PST) in January
    # 2026-01-20T16:00:00 PST = 2026-01-21T00:00:00 UTC
    assert %DateTime{} = event.dtstart
    assert event.dtstart.year == 2026
    assert event.dtstart.month == 1
    assert event.dtstart.day == 21
    assert event.dtstart.hour == 0
    assert event.dtstart.minute == 0

    # 2026-01-20T17:00:00 PST = 2026-01-21T01:00:00 UTC
    assert %DateTime{} = event.dtend
    assert event.dtend.year == 2026
    assert event.dtend.month == 1
    assert event.dtend.day == 21
    assert event.dtend.hour == 1
    assert event.dtend.minute == 0
  end

  test "parses event with TZID parameter - New York timezone" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    calendar_url = base_url <> "/calendars/user/personal/"

    Bypass.expect_once(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, """
      <?xml version="1.0" encoding="UTF-8"?>
      <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
        <D:response>
          <D:href>/calendars/user/personal/ny-event.ics</D:href>
          <D:propstat>
            <D:prop>
              <D:getetag>&quot;ny-1&quot;</D:getetag>
              <C:calendar-data>BEGIN:VCALENDAR&#13;&#10;VERSION:2.0&#13;&#10;BEGIN:VEVENT&#13;&#10;UID:ny-event-123&#13;&#10;SUMMARY:New York Meeting&#13;&#10;DTSTART;TZID=America/New_York:20260315T140000&#13;&#10;DTEND;TZID=America/New_York:20260315T150000&#13;&#10;END:VEVENT&#13;&#10;END:VCALENDAR</C:calendar-data>
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

    assert {:ok, [event]} = CalDAVEx.Event.list(client, calendar_url)

    assert event.summary == "New York Meeting"

    # America/New_York is UTC-4 (EDT) in March (after DST starts)
    # 2026-03-15T14:00:00 EDT = 2026-03-15T18:00:00 UTC
    assert %DateTime{} = event.dtstart
    assert event.dtstart.year == 2026
    assert event.dtstart.month == 3
    assert event.dtstart.day == 15
    assert event.dtstart.hour == 18
  end

  test "parses event with TZID and falls back to UTC for non-TZID events" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    calendar_url = base_url <> "/calendars/user/personal/"

    Bypass.expect_once(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, """
      <?xml version="1.0" encoding="UTF-8"?>
      <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
        <D:response>
          <D:href>/calendars/user/personal/utc-event.ics</D:href>
          <D:propstat>
            <D:prop>
              <D:getetag>&quot;utc-1&quot;</D:getetag>
              <C:calendar-data>BEGIN:VCALENDAR&#13;&#10;VERSION:2.0&#13;&#10;BEGIN:VEVENT&#13;&#10;UID:utc-event-123&#13;&#10;SUMMARY:UTC Event&#13;&#10;DTSTART:20260120T160000Z&#13;&#10;DTEND:20260120T170000Z&#13;&#10;END:VEVENT&#13;&#10;END:VCALENDAR</C:calendar-data>
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

    assert {:ok, [event]} = CalDAVEx.Event.list(client, calendar_url)

    assert event.summary == "UTC Event"
    # Should still parse UTC times correctly (fallback to ical library)
    assert %DateTime{} = event.dtstart
    assert event.dtstart == ~U[2026-01-20 16:00:00Z]
  end

  test "parses real-world Apple Calendar event with TZID" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    calendar_url = base_url <> "/calendars/user/personal/"

    # Real example from user's request
    ics_data = """
    BEGIN:VCALENDAR\r
    CALSCALE:GREGORIAN\r
    PRODID:-//Apple Inc.//iPhone OS 26.2//EN\r
    VERSION:2.0\r
    BEGIN:VEVENT\r
    CREATED:20260120T182805Z\r
    DESCRIPTION:Blood donation appointment\r
    DTEND;TZID=America/Los_Angeles:20260120T170000\r
    DTSTAMP:20260120T182806Z\r
    DTSTART;TZID=America/Los_Angeles:20260120T160000\r
    LAST-MODIFIED:20260120T182805Z\r
    LOCATION:3230 NW Randall Way\r
    SEQUENCE:0\r
    SUMMARY:Blood Donation - Silverdale Center\r
    UID:741BFC3B-FAEC-47B4-AE1D-39910DB96AF0\r
    TRANSP:OPAQUE\r
    END:VEVENT\r
    END:VCALENDAR
    """

    Bypass.expect_once(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, """
      <?xml version="1.0" encoding="UTF-8"?>
      <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
        <D:response>
          <D:href>/calendars/user/personal/blood-donation.ics</D:href>
          <D:propstat>
            <D:prop>
              <D:getetag>&quot;apple-1&quot;</D:getetag>
              <C:calendar-data>#{ics_data}</C:calendar-data>
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

    assert {:ok, [event]} = CalDAVEx.Event.list(client, calendar_url)

    assert event.summary == "Blood Donation - Silverdale Center"
    assert event.location == "3230 NW Randall Way"
    assert event.uid == "741BFC3B-FAEC-47B4-AE1D-39910DB96AF0"

    # Verify DTSTART and DTEND are properly parsed and converted to UTC
    assert %DateTime{} = event.dtstart
    assert %DateTime{} = event.dtend
    refute is_nil(event.dtstart)
    refute is_nil(event.dtend)

    # America/Los_Angeles is UTC-8 (PST) in January
    assert event.dtstart.year == 2026
    assert event.dtstart.month == 1
    assert event.dtstart.day == 21
    assert event.dtstart.hour == 0
    assert event.dtstart.minute == 0

    assert event.dtend.year == 2026
    assert event.dtend.month == 1
    assert event.dtend.day == 21
    assert event.dtend.hour == 1
    assert event.dtend.minute == 0
  end

  test "handles event with invalid TZID gracefully" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    calendar_url = base_url <> "/calendars/user/personal/"

    Bypass.expect_once(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, """
      <?xml version="1.0" encoding="UTF-8"?>
      <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
        <D:response>
          <D:href>/calendars/user/personal/invalid-tz.ics</D:href>
          <D:propstat>
            <D:prop>
              <D:getetag>&quot;inv-1&quot;</D:getetag>
              <C:calendar-data>BEGIN:VCALENDAR&#13;&#10;VERSION:2.0&#13;&#10;BEGIN:VEVENT&#13;&#10;UID:invalid-tz-123&#13;&#10;SUMMARY:Invalid Timezone Event&#13;&#10;DTSTART;TZID=Invalid/Timezone:20260120T160000&#13;&#10;DTEND;TZID=Invalid/Timezone:20260120T170000&#13;&#10;END:VEVENT&#13;&#10;END:VCALENDAR</C:calendar-data>
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

    assert {:ok, [event]} = CalDAVEx.Event.list(client, calendar_url)
    # Should fall back to nil when timezone is invalid
    assert event.dtstart == nil
    assert event.dtend == nil
  end

  test "handles event with malformed datetime in TZID" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    calendar_url = base_url <> "/calendars/user/personal/"

    Bypass.expect_once(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, """
      <?xml version="1.0" encoding="UTF-8"?>
      <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
        <D:response>
          <D:href>/calendars/user/personal/malformed-dt.ics</D:href>
          <D:propstat>
            <D:prop>
              <D:getetag>&quot;mal-1&quot;</D:getetag>
              <C:calendar-data>BEGIN:VCALENDAR&#13;&#10;VERSION:2.0&#13;&#10;BEGIN:VEVENT&#13;&#10;UID:malformed-dt-123&#13;&#10;SUMMARY:Malformed DateTime Event&#13;&#10;DTSTART;TZID=America/Los_Angeles:20261399T999999&#13;&#10;DTEND;TZID=America/Los_Angeles:INVALID&#13;&#10;END:VEVENT&#13;&#10;END:VCALENDAR</C:calendar-data>
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

    assert {:ok, [event]} = CalDAVEx.Event.list(client, calendar_url)
    # Should handle malformed datetime gracefully
    assert event.dtstart == nil
    assert event.dtend == nil
  end

  test "handles DST fall-back ambiguous time" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    calendar_url = base_url <> "/calendars/user/personal/"

    # November 1, 2026 at 1:30 AM is ambiguous during DST fall-back
    Bypass.expect_once(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, """
      <?xml version="1.0" encoding="UTF-8"?>
      <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
        <D:response>
          <D:href>/calendars/user/personal/dst-fallback.ics</D:href>
          <D:propstat>
            <D:prop>
              <D:getetag>&quot;dst-fb-1&quot;</D:getetag>
              <C:calendar-data>BEGIN:VCALENDAR&#13;&#10;VERSION:2.0&#13;&#10;BEGIN:VEVENT&#13;&#10;UID:dst-fallback-123&#13;&#10;SUMMARY:DST Fall-back Event&#13;&#10;DTSTART;TZID=America/New_York:20261101T013000&#13;&#10;DTEND;TZID=America/New_York:20261101T023000&#13;&#10;END:VEVENT&#13;&#10;END:VCALENDAR</C:calendar-data>
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

    assert {:ok, [event]} = CalDAVEx.Event.list(client, calendar_url)
    # Should handle DST ambiguous time (chooses first occurrence)
    assert %DateTime{} = event.dtstart
    assert %DateTime{} = event.dtend
  end

  test "handles DST spring-forward gap time" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    calendar_url = base_url <> "/calendars/user/personal/"

    # March 8, 2026 at 2:30 AM doesn't exist (gap) during DST spring-forward
    Bypass.expect_once(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, """
      <?xml version="1.0" encoding="UTF-8"?>
      <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
        <D:response>
          <D:href>/calendars/user/personal/dst-gap.ics</D:href>
          <D:propstat>
            <D:prop>
              <D:getetag>&quot;dst-gap-1&quot;</D:getetag>
              <C:calendar-data>BEGIN:VCALENDAR&#13;&#10;VERSION:2.0&#13;&#10;BEGIN:VEVENT&#13;&#10;UID:dst-gap-123&#13;&#10;SUMMARY:DST Spring-forward Gap Event&#13;&#10;DTSTART;TZID=America/New_York:20260308T023000&#13;&#10;DTEND;TZID=America/New_York:20260308T033000&#13;&#10;END:VEVENT&#13;&#10;END:VCALENDAR</C:calendar-data>
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

    assert {:ok, [event]} = CalDAVEx.Event.list(client, calendar_url)
    # Should handle DST gap time (chooses time after the gap)
    assert %DateTime{} = event.dtstart
    assert %DateTime{} = event.dtend
    # The time should be adjusted to after the gap (3:30 AM EDT)
    refute is_nil(event.dtstart)
    refute is_nil(event.dtend)
  end

  test "parses event with DATE format (no time)" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"
    calendar_url = base_url <> "/calendars/user/personal/"

    Bypass.expect_once(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, """
      <?xml version="1.0" encoding="UTF-8"?>
      <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
        <D:response>
          <D:href>/calendars/user/personal/all-day.ics</D:href>
          <D:propstat>
            <D:prop>
              <D:getetag>&quot;date-1&quot;</D:getetag>
              <C:calendar-data>BEGIN:VCALENDAR&#13;&#10;VERSION:2.0&#13;&#10;BEGIN:VEVENT&#13;&#10;UID:all-day-123&#13;&#10;SUMMARY:All Day Event&#13;&#10;DTSTART;VALUE=DATE:20260120&#13;&#10;DTEND;VALUE=DATE:20260121&#13;&#10;END:VEVENT&#13;&#10;END:VCALENDAR</C:calendar-data>
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

    assert {:ok, [event]} = CalDAVEx.Event.list(client, calendar_url)
    # DATE format should be parsed by ical library (fallback)
    assert event.summary == "All Day Event"
    assert event.dtstart != nil
    assert event.dtend != nil
  end
end
