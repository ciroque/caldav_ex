defmodule CalDAVEx.Calendar do
  alias CalDAVEx.{HTTP, Types.Calendar, XML}

  def list(client, discovery_info) do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <D:propfind xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:CS="http://calendarserver.org/ns/">
      <D:prop>
        <D:displayname/>
        <C:calendar-description/>
        <CS:getctag/>
        <D:resourcetype/>
      </D:prop>
    </D:propfind>
    """

    url = discovery_info.calendar_home_set_url

    case HTTP.request(client, :propfind, url, [{"depth", "1"}], xml) do
      {:ok, %{body: body}} ->
        with {:ok, responses} <- XML.parse_multistatus(body, client.config.base_url) do
          calendars =
            responses
            |> Enum.filter(& &1.href)
            |> Enum.filter(& &1.is_calendar)
            |> Enum.map(fn response ->
              %Calendar{
                url: response.href,
                display_name: response.display_name,
                description: response.description,
                ctag: response.ctag,
                is_calendar: response.is_calendar
              }
            end)

          {:ok, calendars}
        end

      error ->
        error
    end
  end
end
