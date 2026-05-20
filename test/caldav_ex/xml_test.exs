defmodule CalDAVEx.XMLTest do
  use ExUnit.Case, async: true

  alias CalDAVEx.XML

  test "parses multistatus with successful propstat only" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
      <D:response>
        <D:href>/calendars/user/work/</D:href>
        <D:propstat>
          <D:prop>
            <D:displayname>Work Calendar</D:displayname>
            <D:getctag>abc123</D:getctag>
          </D:prop>
          <D:status>HTTP/1.1 200 OK</D:status>
        </D:propstat>
      </D:response>
    </D:multistatus>
    """

    assert {:ok, [response]} = XML.parse_multistatus(xml, "https://caldav.example.com")
    assert response.href == "https://caldav.example.com/calendars/user/work/"
    assert response.display_name == "Work Calendar"
    assert response.ctag == "abc123"
  end

  test "ignores properties from failed propstat blocks" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
      <D:response>
        <D:href>/calendars/user/work/</D:href>
        <D:propstat>
          <D:prop>
            <D:displayname>Work Calendar</D:displayname>
            <D:getctag>abc123</D:getctag>
          </D:prop>
          <D:status>HTTP/1.1 200 OK</D:status>
        </D:propstat>
        <D:propstat>
          <D:prop>
            <C:calendar-description>This should be ignored</C:calendar-description>
          </D:prop>
          <D:status>HTTP/1.1 404 Not Found</D:status>
        </D:propstat>
      </D:response>
    </D:multistatus>
    """

    assert {:ok, [response]} = XML.parse_multistatus(xml, "https://caldav.example.com")
    assert response.href == "https://caldav.example.com/calendars/user/work/"
    assert response.display_name == "Work Calendar"
    assert response.ctag == "abc123"
    assert response.description == nil
  end

  test "handles multiple responses with mixed propstat statuses" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
      <D:response>
        <D:href>/calendars/user/work/</D:href>
        <D:propstat>
          <D:prop>
            <D:displayname>Work</D:displayname>
          </D:prop>
          <D:status>HTTP/1.1 200 OK</D:status>
        </D:propstat>
        <D:propstat>
          <D:prop>
            <D:getctag>should-be-ignored</D:getctag>
          </D:prop>
          <D:status>HTTP/1.1 404 Not Found</D:status>
        </D:propstat>
      </D:response>
      <D:response>
        <D:href>/calendars/user/personal/</D:href>
        <D:propstat>
          <D:prop>
            <D:displayname>Personal</D:displayname>
            <D:getctag>xyz789</D:getctag>
          </D:prop>
          <D:status>HTTP/1.1 200 OK</D:status>
        </D:propstat>
      </D:response>
    </D:multistatus>
    """

    assert {:ok, responses} = XML.parse_multistatus(xml, "https://caldav.example.com")
    assert length(responses) == 2

    [work, personal] = responses

    assert work.display_name == "Work"
    assert work.ctag == nil

    assert personal.display_name == "Personal"
    assert personal.ctag == "xyz789"
  end

  test "handles empty multistatus" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <D:multistatus xmlns:D="DAV:">
    </D:multistatus>
    """

    assert {:ok, responses} = XML.parse_multistatus(xml, "https://caldav.example.com")
    assert responses == []
  end

  test "handles malformed XML" do
    xml = "<invalid>xml"

    assert {:error, error} = XML.parse_multistatus(xml, "https://caldav.example.com")
    assert error.type == :xml
  end

  test "handles response without href" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <D:multistatus xmlns:D="DAV:">
      <D:response>
        <D:propstat>
          <D:prop>
            <D:displayname>Test</D:displayname>
          </D:prop>
          <D:status>HTTP/1.1 200 OK</D:status>
        </D:propstat>
      </D:response>
    </D:multistatus>
    """

    assert {:ok, [response]} = XML.parse_multistatus(xml, "https://caldav.example.com")
    assert response.href == nil
    assert response.display_name == "Test"
  end

  test "handles relative URLs" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <D:multistatus xmlns:D="DAV:">
      <D:response>
        <D:href>/calendars/user/cal/</D:href>
        <D:propstat>
          <D:prop>
            <D:displayname>Calendar</D:displayname>
          </D:prop>
          <D:status>HTTP/1.1 200 OK</D:status>
        </D:propstat>
      </D:response>
    </D:multistatus>
    """

    assert {:ok, [response]} = XML.parse_multistatus(xml, "https://caldav.example.com")
    assert response.href == "https://caldav.example.com/calendars/user/cal/"
  end

  test "handles absolute URLs" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <D:multistatus xmlns:D="DAV:">
      <D:response>
        <D:href>https://other.example.com/cal/</D:href>
        <D:propstat>
          <D:prop>
            <D:displayname>Calendar</D:displayname>
          </D:prop>
          <D:status>HTTP/1.1 200 OK</D:status>
        </D:propstat>
      </D:response>
    </D:multistatus>
    """

    assert {:ok, [response]} = XML.parse_multistatus(xml, "https://caldav.example.com")
    assert response.href == "https://other.example.com/cal/"
  end

  test "handles CDATA in calendar data" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
      <D:response>
        <D:href>/calendars/user/event.ics</D:href>
        <D:propstat>
          <D:prop>
            <C:calendar-data><![CDATA[BEGIN:VCALENDAR
    VERSION:2.0
    END:VCALENDAR]]></C:calendar-data>
          </D:prop>
          <D:status>HTTP/1.1 200 OK</D:status>
        </D:propstat>
      </D:response>
    </D:multistatus>
    """

    assert {:ok, [response]} = XML.parse_multistatus(xml, "https://caldav.example.com")
    assert response.calendar_data =~ "BEGIN:VCALENDAR"
  end

  test "identifies calendar resourcetype correctly" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
      <D:response>
        <D:href>/calendars/user/work/</D:href>
        <D:propstat>
          <D:prop>
            <D:displayname>Work</D:displayname>
            <D:resourcetype>
              <D:collection/>
              <C:calendar/>
            </D:resourcetype>
          </D:prop>
          <D:status>HTTP/1.1 200 OK</D:status>
        </D:propstat>
      </D:response>
    </D:multistatus>
    """

    assert {:ok, [response]} = XML.parse_multistatus(xml, "https://caldav.example.com")
    assert response.is_calendar == true
  end

  test "handles resourcetype without calendar element" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <D:multistatus xmlns:D="DAV:">
      <D:response>
        <D:href>/files/document.txt</D:href>
        <D:propstat>
          <D:prop>
            <D:displayname>Document</D:displayname>
            <D:resourcetype>
              <D:collection/>
            </D:resourcetype>
          </D:prop>
          <D:status>HTTP/1.1 200 OK</D:status>
        </D:propstat>
      </D:response>
    </D:multistatus>
    """

    assert {:ok, [response]} = XML.parse_multistatus(xml, "https://caldav.example.com")
    assert response.is_calendar == false
  end

  test "handles missing resourcetype" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <D:multistatus xmlns:D="DAV:">
      <D:response>
        <D:href>/files/document.txt</D:href>
        <D:propstat>
          <D:prop>
            <D:displayname>Document</D:displayname>
          </D:prop>
          <D:status>HTTP/1.1 200 OK</D:status>
        </D:propstat>
      </D:response>
    </D:multistatus>
    """

    assert {:ok, [response]} = XML.parse_multistatus(xml, "https://caldav.example.com")
    assert response.is_calendar == false
  end

  test "handles calendar description" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
      <D:response>
        <D:href>/calendars/user/work/</D:href>
        <D:propstat>
          <D:prop>
            <D:displayname>Work</D:displayname>
            <C:calendar-description>My work calendar</C:calendar-description>
          </D:prop>
          <D:status>HTTP/1.1 200 OK</D:status>
        </D:propstat>
      </D:response>
    </D:multistatus>
    """

    assert {:ok, [response]} = XML.parse_multistatus(xml, "https://caldav.example.com")
    assert response.description == "My work calendar"
  end
end
