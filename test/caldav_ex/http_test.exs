defmodule CalDAVEx.HTTPTest do
  use ExUnit.Case, async: true

  alias CalDAVEx.HTTP

  test "converts WebDAV method atoms to uppercase strings" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"

    Bypass.expect_once(bypass, fn conn ->
      assert "PROPFIND" == conn.method
      Plug.Conn.resp(conn, 200, "")
    end)

    client =
      base_url
      |> CalDAVEx.new_config(CalDAVEx.no_auth())
      |> CalDAVEx.new_client()

    assert {:ok, _} = HTTP.request(client, :propfind, base_url)
  end

  test "passes through standard HTTP methods" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"

    Bypass.expect_once(bypass, fn conn ->
      assert "GET" == conn.method
      Plug.Conn.resp(conn, 200, "")
    end)

    client =
      base_url
      |> CalDAVEx.new_config(CalDAVEx.no_auth())
      |> CalDAVEx.new_client()

    assert {:ok, _} = HTTP.request(client, :get, base_url)
  end

  test "returns error for non-2xx status codes" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"

    Bypass.expect_once(bypass, fn conn ->
      Plug.Conn.resp(conn, 404, "Not Found")
    end)

    client =
      base_url
      |> CalDAVEx.new_config(CalDAVEx.no_auth())
      |> CalDAVEx.new_client()

    assert {:error, error} = HTTP.request(client, :get, base_url)
    assert error.type == :http
    assert error.message == "HTTP 404"
    assert error.details == "Not Found"
  end

  test "includes custom headers in request" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"

    Bypass.expect_once(bypass, fn conn ->
      assert ["1"] = Plug.Conn.get_req_header(conn, "depth")
      Plug.Conn.resp(conn, 200, "")
    end)

    client =
      base_url
      |> CalDAVEx.new_config(CalDAVEx.no_auth())
      |> CalDAVEx.new_client()

    assert {:ok, _} = HTTP.request(client, :propfind, base_url, [{"depth", "1"}])
  end

  test "includes request body" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"

    Bypass.expect_once(bypass, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert body == "<test>data</test>"
      Plug.Conn.resp(conn, 200, "")
    end)

    client =
      base_url
      |> CalDAVEx.new_config(CalDAVEx.no_auth())
      |> CalDAVEx.new_client()

    assert {:ok, _} = HTTP.request(client, :propfind, base_url, [], "<test>data</test>")
  end

  test "includes user agent header" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"

    Bypass.expect_once(bypass, fn conn ->
      assert ["CustomAgent/1.0"] = Plug.Conn.get_req_header(conn, "user-agent")
      Plug.Conn.resp(conn, 200, "")
    end)

    client =
      base_url
      |> CalDAVEx.new_config(CalDAVEx.no_auth())
      |> CalDAVEx.with_user_agent("CustomAgent/1.0")
      |> CalDAVEx.new_client()

    assert {:ok, _} = HTTP.request(client, :get, base_url)
  end

  test "includes basic auth header" do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"

    Bypass.expect_once(bypass, fn conn ->
      [auth_header] = Plug.Conn.get_req_header(conn, "authorization")
      assert auth_header =~ "Basic "
      Plug.Conn.resp(conn, 200, "")
    end)

    client =
      base_url
      |> CalDAVEx.new_config(CalDAVEx.basic_auth("user", "pass"))
      |> CalDAVEx.new_client()

    assert {:ok, _} = HTTP.request(client, :get, base_url)
  end
end
