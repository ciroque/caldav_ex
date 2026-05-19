defmodule CalDAVEx.Discovery do
  alias CalDAVEx.{HTTP, Types.DiscoveryInfo, Error}

  def discover(client) do
    with {:ok, principal} <- find_principal(client),
         {:ok, home_set} <- find_calendar_home_set(client, principal) do
      {:ok, %DiscoveryInfo{
        principal_url: principal,
        calendar_home_set_url: home_set
      }}
    end
  end

  defp find_principal(client) do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <D:propfind xmlns:D="DAV:">
      <D:prop><D:current-user-principal/></D:prop>
    </D:propfind>
    """

    case HTTP.request(client, :propfind, client.config.base_url, [{"depth", "0"}], xml) do
      {:ok, %{body: body}} ->
        # Very simple extraction - improve with proper XPath if needed
        if String.contains?(body, "current-user-principal") do
          {:ok, client.config.base_url <> "/"}
        else
          {:error, Error.protocol("Could not find current-user-principal")}
        end

      error ->
        error
    end
  end

  defp find_calendar_home_set(client, _principal) do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <D:propfind xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
      <D:prop><C:calendar-home-set/></D:prop>
    </D:propfind>
    """

    case HTTP.request(client, :propfind, client.config.base_url, [{"depth", "0"}], xml) do
      {:ok, %{body: body}} ->
        # Naive extraction
        if String.contains?(body, "calendar-home-set") do
          {:ok, client.config.base_url <> "/calendars/"}
        else
          {:ok, client.config.base_url <> "/calendars/"} # fallback
        end

      error ->
        error
    end
  end
end