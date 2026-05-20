defmodule CalDAVEx.DiscoveryErrorTest do
  use ExUnit.Case, async: true

  test "returns error when principal not found" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"

    Bypass.expect_once(bypass, fn conn ->
      assert "PROPFIND" == conn.method

      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, """
      <?xml version="1.0" encoding="UTF-8"?>
      <D:multistatus xmlns:D="DAV:">
        <D:response>
          <D:href>/</D:href>
          <D:propstat>
            <D:prop>
            </D:prop>
            <D:status>HTTP/1.1 404 Not Found</D:status>
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
    assert error.message =~ "current-user-principal"
  end

  test "returns error when calendar-home-set not found" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"

    # First request for principal
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
                </D:prop>
                <D:status>HTTP/1.1 404 Not Found</D:status>
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

    assert {:error, error} = CalDAVEx.discover(client)
    assert error.type == :protocol
    assert error.message =~ "calendar-home-set"
  end

  test "returns error on HTTP failure" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"

    Bypass.expect_once(bypass, fn conn ->
      Plug.Conn.resp(conn, 500, "Internal Server Error")
    end)

    client =
      base_url
      |> CalDAVEx.new_config(CalDAVEx.no_auth())
      |> CalDAVEx.new_client()

    assert {:error, error} = CalDAVEx.discover(client)
    assert error.type == :http
  end

  test "returns error on malformed XML" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"

    Bypass.expect_once(bypass, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(207, "<invalid>xml")
    end)

    client =
      base_url
      |> CalDAVEx.new_config(CalDAVEx.no_auth())
      |> CalDAVEx.new_client()

    assert {:error, error} = CalDAVEx.discover(client)
    assert error.type == :xml
  end
end
