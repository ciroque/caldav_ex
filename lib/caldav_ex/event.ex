defmodule CalDAVEx.Event do
  @moduledoc """
  Event operations including listing, retrieval, and CRUD.
  """

  alias CalDAVEx.{HTTP, Types.Event, XML}

  # Precompiled regexes for TZID parameter extraction (performance optimization)
  # Pattern matches exact iCalendar DATE-TIME format: YYYYMMDDTHHmmss
  @dtstart_tzid_regex Regex.compile!(
                        "(?:^|\\r?\\n)DTSTART(?=[;:])(?:;[^:\\r\\n]*)*;TZID=(\"[^\"]+\"|[^;:\\r\\n]+)(?:;[^:\\r\\n]*)*:(\\d{8}T\\d{6})(?:\\r?\\n|$)",
                        "i"
                      )

  @dtend_tzid_regex Regex.compile!(
                      "(?:^|\\r?\\n)DTEND(?=[;:])(?:;[^:\\r\\n]*)*;TZID=(\"[^\"]+\"|[^;:\\r\\n]+)(?:;[^:\\r\\n]*)*:(\\d{8}T\\d{6})(?:\\r?\\n|$)",
                      "i"
                    )

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
      dtend: parsed.dtend,
      uid: parsed.uid,
      description: parsed.description,
      location: parsed.location,
      status: parsed.status,
      rrule: parsed.rrule,
      organizer: parsed.organizer,
      attendees: parsed.attendees
    }
  end

  defp parse_ics(calendar_data) do
    case parse_calendar(calendar_data) do
      %ICal{events: [event | _]} ->
        extract_event_fields(event, calendar_data)

      _ ->
        empty_event_fields()
    end
  end

  defp extract_event_fields(event, calendar_data) do
    # Normalize calendar data: unfold lines per RFC5545 (CRLF + space/tab = continuation)
    normalized_data = unfold_icalendar_lines(calendar_data)

    # Try to parse TZID-based datetimes from normalized ICS data
    dtstart = parse_datetime_with_tzid(normalized_data, "DTSTART") || event.dtstart
    dtend = parse_datetime_with_tzid(normalized_data, "DTEND") || event.dtend

    %{
      summary: event.summary,
      dtstart: dtstart,
      dtend: dtend,
      uid: event.uid,
      description: event.description,
      location: event.location,
      status: extract_status(event),
      rrule: extract_rrule(event),
      organizer: extract_organizer(event),
      attendees: extract_attendees(event)
    }
  end

  defp unfold_icalendar_lines(calendar_data) do
    # Per RFC5545 section 3.1: Lines are delimited by CRLF.
    # A line that begins with a space or tab is a continuation of the previous line.
    # Remove CRLF + space/tab to unfold continuation lines.
    calendar_data
    |> String.replace(~r/\r?\n[ \t]/, "")
  end

  defp empty_event_fields do
    %{
      summary: nil,
      dtstart: nil,
      dtend: nil,
      uid: nil,
      description: nil,
      location: nil,
      status: nil,
      rrule: nil,
      organizer: nil,
      attendees: []
    }
  end

  defp extract_rrule(%{rrule: %ICal.Recurrence{} = rrule}), do: format_rrule(rrule)
  defp extract_rrule(_), do: nil

  defp format_rrule(%ICal.Recurrence{} = rrule) do
    []
    |> add_frequency(rrule.frequency)
    |> add_interval(rrule.interval)
    |> add_count(rrule.count)
    |> add_until(rrule.until)
    |> add_by_day(rrule.by_day)
    |> add_by_month_day(rrule.by_month_day)
    |> add_by_month(rrule.by_month)
    |> Enum.reverse()
    |> Enum.join(";")
  end

  defp add_frequency(parts, nil), do: parts

  defp add_frequency(parts, frequency),
    do: ["FREQ=#{String.upcase(to_string(frequency))}" | parts]

  defp add_interval(parts, nil), do: parts
  defp add_interval(parts, 1), do: parts
  defp add_interval(parts, interval), do: ["INTERVAL=#{interval}" | parts]

  defp add_count(parts, nil), do: parts
  defp add_count(parts, count), do: ["COUNT=#{count}" | parts]

  defp add_until(parts, nil), do: parts
  defp add_until(parts, until), do: ["UNTIL=#{format_until(until)}" | parts]

  defp add_by_day(parts, nil), do: parts
  defp add_by_day(parts, []), do: parts
  defp add_by_day(parts, by_day), do: ["BYDAY=#{format_by_day(by_day)}" | parts]

  defp add_by_month_day(parts, nil), do: parts

  defp add_by_month_day(parts, by_month_day),
    do: ["BYMONTHDAY=#{Enum.join(by_month_day, ",")}" | parts]

  defp add_by_month(parts, nil), do: parts
  defp add_by_month(parts, by_month), do: ["BYMONTH=#{Enum.join(by_month, ",")}" | parts]

  defp format_until(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y%m%dT%H%M%SZ")
  defp format_until(%Date{} = d), do: Calendar.strftime(d, "%Y%m%d")
  defp format_until(_), do: ""

  defp format_by_day(by_day) do
    Enum.map_join(by_day, ",", fn
      {0, day} -> String.upcase(to_string(day)) |> String.slice(0, 2)
      {n, day} -> "#{n}#{String.upcase(to_string(day)) |> String.slice(0, 2)}"
    end)
  end

  defp extract_status(%{status: status}) when is_atom(status) and not is_nil(status) do
    status |> to_string() |> String.upcase()
  end

  defp extract_status(_), do: nil

  defp extract_organizer(%{organizer: organizer})
       when is_binary(organizer) and not is_nil(organizer) do
    organizer
  end

  defp extract_organizer(_), do: nil

  defp extract_attendees(%{attendees: attendees}) do
    Enum.map(attendees, fn
      %ICal.Attendee{name: name} -> name
      name when is_binary(name) -> name
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_datetime_with_tzid(calendar_data, "DTSTART") do
    case Regex.run(@dtstart_tzid_regex, calendar_data) do
      [_, tzid, datetime_str] ->
        parse_datetime_in_timezone(datetime_str, normalize_tzid(tzid))

      _ ->
        nil
    end
  end

  defp parse_datetime_with_tzid(calendar_data, "DTEND") do
    case Regex.run(@dtend_tzid_regex, calendar_data) do
      [_, tzid, datetime_str] ->
        parse_datetime_in_timezone(datetime_str, normalize_tzid(tzid))

      _ ->
        nil
    end
  end

  defp normalize_tzid("\"" <> tzid) do
    String.trim_trailing(tzid, "\"")
  end

  defp normalize_tzid(tzid), do: tzid

  defp parse_datetime_in_timezone(datetime_str, tzid) do
    # Parse datetime format: YYYYMMDDTHHmmss
    case parse_local_datetime(datetime_str) do
      {:ok, naive_dt} ->
        convert_to_utc(naive_dt, tzid)

      _ ->
        nil
    end
  end

  defp parse_local_datetime(datetime_str) do
    # Format: YYYYMMDDTHHmmss
    case Regex.run(~r/(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})/, datetime_str) do
      [_, year, month, day, hour, minute, second] ->
        NaiveDateTime.new(
          String.to_integer(year),
          String.to_integer(month),
          String.to_integer(day),
          String.to_integer(hour),
          String.to_integer(minute),
          String.to_integer(second)
        )

      _ ->
        :error
    end
  end

  defp convert_to_utc(naive_dt, tzid) do
    # Use the Tz library to convert from the specified timezone to UTC
    # Use 3-arity functions with explicit database so library works without consumer config
    with datetime when not is_nil(datetime) <- resolve_timezone(naive_dt, tzid),
         {:ok, utc_datetime} <- DateTime.shift_zone(datetime, "Etc/UTC", Tz.TimeZoneDatabase) do
      utc_datetime
    else
      _ -> nil
    end
  end

  defp resolve_timezone(naive_dt, tzid) do
    # Use 3-arity from_naive with explicit Tz.TimeZoneDatabase
    # This ensures the library works for consumers without requiring config
    case DateTime.from_naive(naive_dt, tzid, Tz.TimeZoneDatabase) do
      {:ok, datetime} ->
        datetime

      {:ambiguous, dt1, _dt2} ->
        # During fall-back DST transitions, choose the first occurrence
        dt1

      {:gap, _dt_before, dt_after} ->
        # During spring-forward DST transitions, choose the time after the gap
        dt_after

      {:error, _reason} ->
        nil
    end
  end

  defp parse_calendar(calendar_data) do
    ICal.from_ics(calendar_data)
  rescue
    _ -> nil
  end

  defp get_header(headers, key) do
    headers
    |> Enum.find_value(fn {k, v} -> if String.downcase(k) == key, do: v end)
    |> normalize_header_value()
  end

  defp normalize_header_value([value | _]), do: value
  defp normalize_header_value(value) when is_binary(value), do: value
  defp normalize_header_value(_), do: nil
end
