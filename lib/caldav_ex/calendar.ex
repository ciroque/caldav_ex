defmodule CalDAVEx.Calendar do
  @moduledoc """
  Calendar listing operations against a CalDAV server.
  """

  alias CalDAVEx.{HTTP, Types.Calendar, XML}

  @doc """
  Lists all calendars under the user's calendar-home-set.

  Issues a `PROPFIND` with `Depth: 1` requesting `displayname`,
  `calendar-description`, `getctag`, and `resourcetype` for each child
  resource, then filters the multistatus response to entries whose
  `resourcetype` includes `CALDAV:calendar`.

  ## Parameters

    - `client` - an authenticated `%CalDAVEx.Client{}`
    - `discovery_info` - a `t:CalDAVEx.Types.DiscoveryInfo.t/0` from
      `CalDAVEx.Discovery.discover/1`

  ## Returns

    - `{:ok, [%CalDAVEx.Types.Calendar{}]}` on success
    - `{:error, %CalDAVEx.Error{}}` on transport, HTTP, or XML failures

  ## Examples

      {:ok, info} = CalDAVEx.discover(client)
      {:ok, calendars} = CalDAVEx.Calendar.list(client, info)
  """
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
          calendars = build_calendars(responses)
          {:ok, calendars}
        end

      error ->
        error
    end
  end

  defp build_calendars(responses) do
    responses
    |> Enum.filter(&(&1.href && &1.is_calendar))
    |> Enum.map(&response_to_calendar/1)
  end

  defp response_to_calendar(response) do
    %Calendar{
      url: response.href,
      display_name: response.display_name,
      description: response.description,
      ctag: response.ctag,
      is_calendar: response.is_calendar
    }
  end
end
