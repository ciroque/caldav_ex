defmodule CalDAVEx.Event do
  alias CalDAVEx.{HTTP, Types.Event, XML}

  def list(client, calendar_url, opts \\ []) do
    xml = calendar_query(opts)

    case HTTP.request(client, :report, calendar_url, [{"depth", "1"}], xml) do
      {:ok, %{body: body}} ->
        with {:ok, responses} <- XML.parse_multistatus(body, client.config.base_url) do
          events =
            responses
            |> Enum.filter(& &1.calendar_data)
            |> Enum.map(&build_event/1)

          {:ok, events}
        end

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

  defp calendar_query(opts) do
    time_range = time_range(Keyword.get(opts, :from), Keyword.get(opts, :to))

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <C:calendar-query xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:D="DAV:">
      <D:prop>
        <D:getetag/>
        <C:calendar-data/>
      </D:prop>
      <C:filter>
        <C:comp-filter name="VCALENDAR">
          <C:comp-filter name="VEVENT">#{time_range}</C:comp-filter>
        </C:comp-filter>
      </C:filter>
    </C:calendar-query>
    """
  end

  defp time_range(nil, nil), do: ""

  defp time_range(from, to) do
    start_attr = if from, do: " start=\"#{format_caldav_datetime(from)}\"", else: ""
    end_attr = if to, do: " end=\"#{format_caldav_datetime(to)}\"", else: ""
    "<C:time-range#{start_attr}#{end_attr}/>"
  end

  defp format_caldav_datetime(%DateTime{} = datetime) do
    datetime
    |> DateTime.shift_zone!("Etc/UTC")
    |> Calendar.strftime("%Y%m%dT%H%M%SZ")
  end

  defp build_event(response) do
    parsed = parse_ics(response.calendar_data)

    %Event{
      href: response.href,
      etag: response.etag,
      calendar_data: response.calendar_data,
      summary: parsed.summary,
      dtstart: parsed.dtstart,
      dtend: parsed.dtend
    }
  end

  defp parse_ics(calendar_data) do
    case parse_calendar(calendar_data) do
      %ICal{events: [event | _]} ->
        %{summary: event.summary, dtstart: event.dtstart, dtend: event.dtend}

      {:ok, %ICal{events: [event | _]}} ->
        %{summary: event.summary, dtstart: event.dtstart, dtend: event.dtend}

      _ ->
        %{summary: nil, dtstart: nil, dtend: nil}
    end
  end

  defp parse_calendar(calendar_data) do
    ICal.from_ics(calendar_data)
  rescue
    _ -> nil
  end

  defp get_header(headers, key) do
    case Enum.find_value(headers, fn {k, v} -> if String.downcase(k) == key, do: v end) do
      [value | _] -> value
      value when is_binary(value) -> value
      _ -> nil
    end
  end
end
