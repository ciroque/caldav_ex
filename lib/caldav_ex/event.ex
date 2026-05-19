defmodule CalDAVEx.Event do
  alias CalDAVEx.{HTTP, Types.Event, Error}

  def list(client, calendar_url) do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <C:calendar-query xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:D="DAV:">
      <D:prop>
        <D:getetag/>
        <C:calendar-data/>
      </D:prop>
      <C:filter>
        <C:comp-filter name="VCALENDAR"/>
      </C:filter>
    </C:calendar-query>
    """

    case HTTP.request(client, :report, calendar_url, [{"depth", "1"}], xml) do
      {:ok, %{body: body}} ->
        # Placeholder until full Saxy parser
        {:ok, []}

      error ->
        error
    end
  end

  def get(client, event_url) do
    case HTTP.request(client, :get, event_url) do
      {:ok, %{body: body, headers: headers}} ->
        etag = get_header(headers, "etag")
        {:ok, %Event{href: event_url, etag: etag, calendar_data: body}}

      error ->
        error
    end
  end

  def create(client, calendar_url, filename, ics_data) do
    url = String.trim_trailing(calendar_url, "/") <> "/" <> filename
    headers = [{"if-none-match", "*"}]

    case HTTP.request(client, :put, url, headers, ics_data) do
      {:ok, _} -> {:ok, %Event{href: url}}
      error -> error
    end
  end

  def update(client, event_url, ics_data, etag) do
    headers = if etag, do: [{"if-match", etag}], else: []
    HTTP.request(client, :put, event_url, headers, ics_data)
  end

  def delete(client, event_url, etag) do
    headers = if etag, do: [{"if-match", etag}], else: []
    HTTP.request(client, :delete, event_url, headers)
  end

  defp get_header(headers, key) do
    headers
    |> Enum.find_value(fn {k, v} -> if String.downcase(k) == key, do: v end)
  end
end