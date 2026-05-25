defmodule CalDAVEx.Event do
  @moduledoc """
  Event operations: listing, retrieval, and CRUD against a CalDAV calendar.

  Listing uses the `REPORT` method with a `calendar-query` filter. Server-side
  recurrence expansion via `<C:expand>` is supported through the
  `:expand_recurrences` option on `list/3`.

  Timed events whose `DTSTART`/`DTEND` carry a `TZID` parameter are normalized
  to UTC `DateTime` values using `Tz.TimeZoneDatabase`; ambiguous (fall-back)
  times resolve to the first occurrence and gap (spring-forward) times to the
  time immediately after the gap.
  """

  alias CalDAVEx.{Error, HTTP, Types.Event, XML}

  @typedoc """
  Options accepted by `list/3`.
  """
  @type list_opt ::
          {:from, DateTime.t() | nil}
          | {:to, DateTime.t() | nil}
          | {:expand_recurrences, boolean()}

  @typedoc "Keyword list of `t:list_opt/0` values."
  @type list_opts :: [list_opt()]

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

  @doc """
  Lists events from a calendar, optionally filtered by a time range.

  Returned events are not guaranteed to be unique by `href` or `etag`: a
  single CalDAV resource whose `calendar-data` contains multiple `VEVENT`
  components (e.g. a recurring master plus `RECURRENCE-ID` overrides, or
  occurrences produced by `<C:expand>`) yields one `%CalDAVEx.Types.Event{}`
  per `VEVENT` sharing the same `href`/`etag`.

  ## Parameters

    - `client` - an authenticated `%CalDAVEx.Client{}`
    - `calendar_url` - the full URL of the calendar collection
    - `opts` - keyword list:
      - `:from` - start of the time range (`t:DateTime.t/0` or `nil`)
      - `:to` - end of the time range (`t:DateTime.t/0` or `nil`)
      - `:expand_recurrences` - when `true`, asks the server to expand
        recurring events via `<C:expand>`. Both `:from` and `:to` MUST be
        provided when this is `true`; otherwise an
        `{:error, %CalDAVEx.Error{type: :invalid_argument}}` is returned.
        Server support varies. Defaults to `false`.

  ## Returns

    - `{:ok, [%CalDAVEx.Types.Event{}]}` on success
    - `{:error, %CalDAVEx.Error{}}` on validation, transport, HTTP, or XML failures

  ## Examples

      {:ok, events} = CalDAVEx.Event.list(client, calendar.url,
        from: ~U[2025-05-01 00:00:00Z],
        to: ~U[2025-05-31 23:59:59Z]
      )
  """
  @spec list(CalDAVEx.Client.t(), String.t(), list_opts()) ::
          {:ok, [Event.t()]} | {:error, CalDAVEx.Error.t()}
  def list(client, calendar_url, opts \\ []) do
    with :ok <- validate_opts(opts),
         xml = calendar_query(opts),
         {:ok, %{body: body}} <-
           HTTP.request(client, :report, calendar_url, [{"depth", "1"}], xml),
         {:ok, responses} <- XML.parse_multistatus(body, client.config.base_url) do
      events =
        responses
        |> Enum.filter(& &1.calendar_data)
        |> Enum.flat_map(&build_events/1)

      {:ok, events}
    end
  end

  defp validate_opts(opts) do
    from = Keyword.get(opts, :from)
    to = Keyword.get(opts, :to)
    expand? = Keyword.get(opts, :expand_recurrences, false)

    cond do
      not valid_bound?(from) ->
        {:error, Error.invalid_argument(":from must be a %DateTime{} or nil")}

      not valid_bound?(to) ->
        {:error, Error.invalid_argument(":to must be a %DateTime{} or nil")}

      expand? and (is_nil(from) or is_nil(to)) ->
        {:error, Error.invalid_argument("expand_recurrences: true requires both :from and :to")}

      true ->
        :ok
    end
  end

  defp valid_bound?(nil), do: true
  defp valid_bound?(%DateTime{}), do: true
  defp valid_bound?(_), do: false

  @doc """
  Fetches a single event resource by URL.

  Returns an event populated with the raw `calendar_data` body and the
  `ETag` header (when present). Parsed iCalendar fields such as `summary` or
  `dtstart` are **not** populated by this function; use `list/3` for parsed
  results, or parse `calendar_data` yourself.

  ## Parameters

    - `client` - an authenticated `%CalDAVEx.Client{}`
    - `event_url` - the full URL of the event resource

  ## Returns

    - `{:ok, %CalDAVEx.Types.Event{}}` on success
    - `{:error, %CalDAVEx.Error{}}` on failure
  """
  @spec get(CalDAVEx.Client.t(), String.t()) ::
          {:ok, Event.t()} | {:error, CalDAVEx.Error.t()}
  def get(client, event_url) do
    case HTTP.request(client, :get, event_url) do
      {:ok, %{body: body, headers: headers}} ->
        etag = get_header(headers, "etag")
        {:ok, %Event{href: event_url, etag: etag, calendar_data: body}}

      error ->
        error
    end
  end

  @doc """
  Creates a new event resource by `PUT`ing iCalendar data to the calendar.

  The request includes `If-None-Match: *` to ensure the operation only
  succeeds when no resource exists at the target URL.

  ## Parameters

    - `client` - an authenticated `%CalDAVEx.Client{}`
    - `calendar_url` - the URL of the parent calendar collection
    - `filename` - the resource filename (e.g. `"event.ics"`)
    - `ics_data` - the iCalendar (`VCALENDAR`/`VEVENT`) body as a string

  ## Returns

    - `{:ok, %CalDAVEx.Types.Event{href: url}}` on success
    - `{:error, %CalDAVEx.Error{}}` on failure
  """
  @spec create(CalDAVEx.Client.t(), String.t(), String.t(), iodata()) ::
          {:ok, Event.t()} | {:error, CalDAVEx.Error.t()}
  def create(client, calendar_url, filename, ics_data) do
    url = String.trim_trailing(calendar_url, "/") <> "/" <> filename
    headers = [{"if-none-match", "*"}]

    case HTTP.request(client, :put, url, headers, ics_data) do
      {:ok, _} -> {:ok, %Event{href: url}}
      error -> error
    end
  end

  @doc """
  Replaces an existing event resource with new iCalendar data.

  When `etag` is provided, the request includes `If-Match: <etag>` to perform
  an optimistic-concurrency update; a stale ETag results in a `412` HTTP
  error wrapped in `CalDAVEx.Error`.

  ## Parameters

    - `client` - an authenticated `%CalDAVEx.Client{}`
    - `event_url` - the full URL of the event resource
    - `ics_data` - the replacement iCalendar body
    - `etag` - the previously observed ETag, or `nil` to skip the conditional header

  ## Returns

    - `{:ok, %{status: non_neg_integer, body: term, headers: map}}` on success
    - `{:error, %CalDAVEx.Error{}}` on HTTP, transport, or ETag-mismatch (`412`) failures
  """
  @spec update(CalDAVEx.Client.t(), String.t(), iodata(), String.t() | nil) ::
          {:ok, CalDAVEx.HTTP.response()} | {:error, CalDAVEx.Error.t()}
  def update(client, event_url, ics_data, etag) do
    headers = if etag, do: [{"if-match", etag}], else: []
    HTTP.request(client, :put, event_url, headers, ics_data)
  end

  @doc """
  Deletes an event resource.

  When `etag` is provided, the request includes `If-Match: <etag>` for
  optimistic concurrency.

  ## Parameters

    - `client` - an authenticated `%CalDAVEx.Client{}`
    - `event_url` - the full URL of the event resource
    - `etag` - the previously observed ETag, or `nil` to skip the conditional header

  ## Returns

    - `{:ok, %{status: non_neg_integer, body: term, headers: map}}` on success
    - `{:error, %CalDAVEx.Error{}}` on HTTP, transport, or ETag-mismatch (`412`) failures
  """
  @spec delete(CalDAVEx.Client.t(), String.t(), String.t() | nil) ::
          {:ok, CalDAVEx.HTTP.response()} | {:error, CalDAVEx.Error.t()}
  def delete(client, event_url, etag) do
    headers = if etag, do: [{"if-match", etag}], else: []
    HTTP.request(client, :delete, event_url, headers)
  end

  defp calendar_query(opts) do
    from = Keyword.get(opts, :from)
    to = Keyword.get(opts, :to)
    time_range = time_range(from, to)
    calendar_data = calendar_data_element(opts, from, to)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <C:calendar-query xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:D="DAV:">
      <D:prop>
        <D:getetag/>
        #{calendar_data}
      </D:prop>
      <C:filter>
        <C:comp-filter name="VCALENDAR">
          <C:comp-filter name="VEVENT">#{time_range}</C:comp-filter>
        </C:comp-filter>
      </C:filter>
    </C:calendar-query>
    """
  end

  defp calendar_data_element(opts, %DateTime{} = from, %DateTime{} = to) do
    if Keyword.get(opts, :expand_recurrences, false) do
      "<C:calendar-data><C:expand start=\"#{format_caldav_datetime(from)}\" end=\"#{format_caldav_datetime(to)}\"/></C:calendar-data>"
    else
      "<C:calendar-data/>"
    end
  end

  defp calendar_data_element(_opts, _from, _to), do: "<C:calendar-data/>"

  defp time_range(nil, nil), do: ""

  defp time_range(from, to) do
    start_attr = if from, do: " start=\"#{format_caldav_datetime(from)}\"", else: ""
    end_attr = if to, do: " end=\"#{format_caldav_datetime(to)}\"", else: ""
    "<C:time-range#{start_attr}#{end_attr}/>"
  end

  defp format_caldav_datetime(%DateTime{} = datetime) do
    case DateTime.shift_zone(datetime, "Etc/UTC", Tz.TimeZoneDatabase) do
      {:ok, utc_datetime} ->
        Calendar.strftime(utc_datetime, "%Y%m%dT%H%M%SZ")

      {:error, _} ->
        # Fallback: if shift fails, assume already UTC or use as-is
        Calendar.strftime(datetime, "%Y%m%dT%H%M%SZ")
    end
  end

  defp build_events(response) do
    response.calendar_data
    |> parse_ics()
    |> Enum.map(fn parsed ->
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
    end)
  end

  defp parse_ics(calendar_data) do
    case parse_calendar(calendar_data) do
      # Fast path: single VEVENT — no need to scan/split the resource.
      %ICal{events: [event]} ->
        [extract_event_fields(event, calendar_data)]

      %ICal{events: [_ | _] = events} ->
        blocks = split_vevent_blocks(calendar_data)

        # Pad blocks to the events length with "" so a malformed/unsplit
        # calendar can't leak the first VEVENT's TZID DTSTART/DTEND into
        # sibling events. Single O(n) pass via lazy Stream.
        events
        |> Enum.zip(Stream.concat(blocks, Stream.cycle([""])))
        |> Enum.map(fn {event, block} -> extract_event_fields(event, block) end)

      _ ->
        [empty_event_fields()]
    end
  end

  defp split_vevent_blocks(calendar_data) do
    # iCalendar component names are case-insensitive per RFC 5545 §3.7.
    # Anchor BEGIN:VEVENT/END:VEVENT to line boundaries so that property values
    # legally containing the literal substring "END:VEVENT" (e.g. inside a
    # DESCRIPTION) cannot terminate a block prematurely.
    calendar_data
    |> unfold_icalendar_lines()
    |> then(&Regex.scan(~r/(?:\A|\r?\n)(BEGIN:VEVENT.*?\r?\nEND:VEVENT)(?=\r?\n|\z)/si, &1))
    |> Enum.map(fn [_full, block | _] -> block end)
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
