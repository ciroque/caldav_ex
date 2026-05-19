defmodule CalDAVEx.Calendar do
  alias CalDAVEx.{HTTP, Types.Calendar, Error}

  def list(client, _discovery_info) do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <D:propfind xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
      <D:prop>
        <D:displayname/>
        <C:calendar-description/>
        <D:getctag/>
      </D:prop>
    </D:propfind>
    """

    url = client.config.base_url <> "/calendars/"

    case HTTP.request(client, :propfind, url, [{"depth", "1"}], xml) do
      {:ok, %{body: body}} ->
        # TODO: Proper XML parsing (Saxy) - for now return placeholder
        calendars = [
          %Calendar{
            url: url <> "personal/",
            display_name: "Personal",
            description: "",
            ctag: nil
          }
        ]
        {:ok, calendars}

      error ->
        error
    end
  end
end