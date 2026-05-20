# CalDAVEx

[![Hex.pm](https://img.shields.io/hexpm/v/caldav_ex.svg)](https://hex.pm/packages/caldav_ex)
[![Documentation](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/caldav_ex)
[![CI](https://github.com/ciroque/caldav_ex/actions/workflows/ci.yml/badge.svg)](https://github.com/ciroque/caldav_ex/actions/workflows/ci.yml)
[![License](https://img.shields.io/hexpm/l/caldav_ex.svg)](https://github.com/ciroque/caldav_ex/blob/main/LICENSE)

Elixir CalDAV client library for calendar and event management.

CalDAVEx provides a clean, idiomatic Elixir interface to CalDAV servers with robust XML parsing, iCalendar support, and comprehensive event filtering.

## Acknowledgments

This project was inspired by the [caldav_gleam](https://github.com/RedHelium/caldav_gleam) project, and modeled after the [python-caldav](https://github.com/python-caldav/caldav) library.


## Features

- 🔍 **Discovery** - Automatic principal and calendar-home-set discovery
- 📅 **Calendar Management** - List calendars with metadata (display name, description, ctag)
- 📆 **Event Retrieval** - List and fetch events with time-range filtering
- 🎯 **Robust Parsing** - Saxy-based XML parsing for reliable CalDAV responses
- 📝 **iCalendar Support** - Full iCalendar parsing via the `ical` library
- ⏰ **Time Zones** - Proper timezone handling with `tz`
- ✅ **Well Tested** - Comprehensive test suite with Bypass-backed HTTP mocking

## Installation

Add `caldav_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:caldav_ex, "~> 0.1.0"}
  ]
end
```

## Quick Start

```elixir
# 1. Create a client
config = CalDAVEx.new_config(
  "https://caldav.example.com",
  CalDAVEx.basic_auth("username", "password")
)
client = CalDAVEx.new_client(config)

# 2. Discover calendar endpoints
{:ok, discovery_info} = CalDAVEx.discover(client)

# 3. List calendars
{:ok, calendars} = CalDAVEx.list_calendars(client, discovery_info)

# 4. Get events from a calendar
calendar = List.first(calendars)
{:ok, events} = CalDAVEx.list_events(client, calendar.url)

# 5. Filter events by time range
{:ok, events} = CalDAVEx.list_events(client, calendar.url,
  from: ~U[2025-05-01 00:00:00Z],
  to: ~U[2025-05-31 23:59:59Z]
)

# 6. Get a single event
event = List.first(events)
{:ok, full_event} = CalDAVEx.get_event(client, event.href)
```

## Usage Examples

### Authentication

```elixir
# Basic authentication
config = CalDAVEx.new_config(
  "https://caldav.example.com",
  CalDAVEx.basic_auth("user", "pass")
)

# No authentication (for testing)
config = CalDAVEx.new_config(
  "http://localhost:8080",
  CalDAVEx.no_auth()
)
```

### Working with Events

```elixir
# List all events
{:ok, events} = CalDAVEx.list_events(client, calendar_url)

# Filter by date range
{:ok, events} = CalDAVEx.list_events(client, calendar_url,
  from: DateTime.utc_now(),
  to: DateTime.add(DateTime.utc_now(), 7, :day)
)

# Access event properties
Enum.each(events, fn event ->
  IO.puts("#{event.summary}")
  IO.puts("  Start: #{event.dtstart}")
  IO.puts("  End: #{event.dtend}")
  IO.puts("  ETag: #{event.etag}")
end)

# Calculate event duration
events
|> Enum.filter(fn e -> match?(%DateTime{}, e.dtstart) end)
|> Enum.map(fn e ->
  %{
    summary: e.summary,
    duration_minutes: DateTime.diff(e.dtend, e.dtstart, :minute)
  }
end)
```

### Working with Calendars

```elixir
# List all calendars
{:ok, calendars} = CalDAVEx.list_calendars(client, discovery_info)

# Find a specific calendar
calendar = Enum.find(calendars, fn c -> 
  c.display_name == "Work"
end)

# Access calendar properties
IO.inspect(calendar.display_name)
IO.inspect(calendar.description)
IO.inspect(calendar.ctag)
IO.inspect(calendar.url)
```

### Handling All-Day Events

CalDAVEx correctly distinguishes between timed events and all-day events:

```elixir
events
|> Enum.map(fn e ->
  case e.dtstart do
    %DateTime{} -> 
      IO.puts("Timed event: #{e.summary} at #{e.dtstart}")
    %Date{} -> 
      IO.puts("All-day event: #{e.summary} on #{e.dtstart}")
  end
end)
```

## CalDAV Server Compatibility

CalDAVEx has been tested with:

- ✅ iCloud Calendar
- ✅ Google Calendar (via CalDAV)
- ✅ Nextcloud
- ✅ Radicale

## Data Structures

### Event

```elixir
%CalDAVEx.Types.Event{
  href: "https://caldav.example.com/calendars/user/cal/event.ics",
  etag: "\"abc123\"",
  calendar_data: "BEGIN:VCALENDAR\n...",
  summary: "Team Meeting",
  dtstart: ~U[2025-05-15 14:00:00Z],
  dtend: ~U[2025-05-15 15:00:00Z],
  content_type: "text/calendar"
}
```

### Calendar

```elixir
%CalDAVEx.Types.Calendar{
  url: "https://caldav.example.com/calendars/user/work/",
  display_name: "Work",
  description: "Work calendar",
  ctag: "abc123"
}
```

### DiscoveryInfo

```elixir
%CalDAVEx.Types.DiscoveryInfo{
  principal_url: "https://caldav.example.com/principals/user/",
  calendar_home_set_url: "https://caldav.example.com/calendars/user/"
}
```

## Error Handling

All functions return `{:ok, result}` or `{:error, error}` tuples:

```elixir
case CalDAVEx.list_events(client, calendar_url) do
  {:ok, events} ->
    IO.puts("Found #{length(events)} events")
    
  {:error, %CalDAVEx.Error{type: :http, message: message}} ->
    IO.puts("HTTP error: #{message}")
    
  {:error, %CalDAVEx.Error{type: :xml, message: message}} ->
    IO.puts("XML parsing error: #{message}")
    
  {:error, %CalDAVEx.Error{type: :protocol, message: message}} ->
    IO.puts("CalDAV protocol error: #{message}")
end
```

## Development

```bash
# Get dependencies
mix deps.get

# Run tests
mix test

# Generate documentation
mix docs

# Format code
mix format
```

## Roadmap

- [ ] Calendar resource type filtering
- [ ] Extended event properties (UID, description, location, recurrence)
- [ ] Recurring event expansion
- [ ] Event creation/modification/deletion
- [ ] Calendar creation/deletion
- [ ] Sync token support for efficient updates
- [ ] Free/busy queries

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- Built with [Req](https://github.com/wojtekmach/req) for HTTP
- XML parsing via [Saxy](https://github.com/qcam/saxy)
- iCalendar support from [ical](https://github.com/lpil/ical)
- Timezone handling with [tz](https://github.com/mathieuprog/tz)
