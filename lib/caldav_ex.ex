defmodule CalDAVEx do
  @moduledoc """
  CalDAV client library for calendar and event management.

  CalDAVEx provides a clean, idiomatic Elixir interface to CalDAV servers with
  robust XML parsing, iCalendar support, and comprehensive event filtering.

  ## Quick Start

      # Create a client
      config = CalDAVEx.new_config(
        "https://caldav.example.com",
        CalDAVEx.basic_auth("username", "password")
      )
      client = CalDAVEx.new_client(config)

      # Discover calendar endpoints
      {:ok, discovery_info} = CalDAVEx.discover(client)

      # List calendars
      {:ok, calendars} = CalDAVEx.list_calendars(client, discovery_info)

      # Get events from a calendar
      calendar = List.first(calendars)
      {:ok, events} = CalDAVEx.list_events(client, calendar.url,
        from: ~U[2025-05-01 00:00:00Z],
        to: ~U[2025-05-31 23:59:59Z]
      )

  ## Authentication

  CalDAVEx supports multiple authentication methods:

  - `basic_auth/2` - HTTP Basic authentication
  - `bearer_auth/1` - Bearer token authentication
  - `no_auth/0` - No authentication (for testing)

  ## Error Handling

  All functions return `{:ok, result}` or `{:error, %CalDAVEx.Error{}}` tuples.
  Use `error_to_string/1` to convert errors to human-readable messages.
  """

  alias CalDAVEx.{Calendar, Client, Config, Discovery, Error, Event}

  @doc """
  Returns no authentication configuration.

  Use this for testing or when connecting to servers that don't require authentication.

  ## Examples

      config = CalDAVEx.new_config("http://localhost:8080", CalDAVEx.no_auth())
  """
  def no_auth, do: :no_auth

  @doc """
  Creates HTTP Basic authentication configuration.

  ## Parameters

  - `username` - The username for authentication
  - `password` - The password for authentication

  ## Examples

      auth = CalDAVEx.basic_auth("user@example.com", "secret")
      config = CalDAVEx.new_config("https://caldav.example.com", auth)
  """
  def basic_auth(username, password), do: {:basic, username, password}

  @doc """
  Creates Bearer token authentication configuration.

  ## Parameters

  - `token` - The bearer token for authentication

  ## Examples

      auth = CalDAVEx.bearer_auth("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...")
      config = CalDAVEx.new_config("https://caldav.example.com", auth)
  """
  def bearer_auth(token), do: {:bearer, token}

  @doc """
  Creates a new CalDAV client configuration.

  ## Parameters

  - `base_url` - The base URL of the CalDAV server
  - `auth` - Authentication configuration from `basic_auth/2`, `bearer_auth/1`, or `no_auth/0`

  ## Examples

      config = CalDAVEx.new_config(
        "https://caldav.icloud.com",
        CalDAVEx.basic_auth("user@icloud.com", "app-specific-password")
      )
  """
  def new_config(base_url, auth), do: Config.new(base_url, auth)

  @doc """
  Sets a custom User-Agent header for the client.

  ## Parameters

  - `config` - The client configuration
  - `ua` - The User-Agent string

  ## Examples

      config
      |> CalDAVEx.with_user_agent("MyApp/1.0")
  """
  def with_user_agent(config, ua), do: Config.with_user_agent(config, ua)

  @doc """
  Sets the HTTP request timeout in milliseconds.

  ## Parameters

  - `config` - The client configuration
  - `ms` - Timeout in milliseconds

  ## Examples

      config
      |> CalDAVEx.with_timeout(30_000)
  """
  def with_timeout(config, ms), do: Config.with_timeout(config, ms)

  @doc """
  Creates a new CalDAV client from configuration.

  ## Parameters

  - `config` - The client configuration from `new_config/2`

  ## Examples

      config = CalDAVEx.new_config(base_url, auth)
      client = CalDAVEx.new_client(config)
  """
  def new_client(config), do: Client.new(config)

  @doc """
  Discovers the principal URL and calendar home set URL for the authenticated user.

  This performs two PROPFIND requests:
  1. Queries the base URL for `current-user-principal`
  2. Queries the principal URL for `calendar-home-set`

  ## Parameters

  - `client` - The CalDAV client

  ## Returns

  - `{:ok, %CalDAVEx.Types.DiscoveryInfo{}}` on success
  - `{:error, %CalDAVEx.Error{}}` on failure

  ## Examples

      {:ok, discovery_info} = CalDAVEx.discover(client)
      IO.inspect(discovery_info.principal_url)
      IO.inspect(discovery_info.calendar_home_set_url)
  """
  def discover(client), do: Discovery.discover(client)

  @doc """
  Lists all calendars for the authenticated user.

  ## Parameters

  - `client` - The CalDAV client
  - `discovery_info` - Discovery information from `discover/1`

  ## Returns

  - `{:ok, [%CalDAVEx.Types.Calendar{}]}` on success
  - `{:error, %CalDAVEx.Error{}}` on failure

  ## Examples

      {:ok, discovery_info} = CalDAVEx.discover(client)
      {:ok, calendars} = CalDAVEx.list_calendars(client, discovery_info)

      Enum.each(calendars, fn cal ->
        IO.puts("Calendar: \#{cal.display_name} - \#{cal.url}")
      end)
  """
  def list_calendars(client, discovery_info), do: Calendar.list(client, discovery_info)

  @doc """
  Lists events from a calendar with optional time-range filtering.

  ## Parameters

  - `client` - The CalDAV client
  - `calendar_url` - The URL of the calendar
  - `opts` - Optional keyword list:
    - `:from` - Start of time range (DateTime)
    - `:to` - End of time range (DateTime)

  ## Returns

  - `{:ok, [%CalDAVEx.Types.Event{}]}` on success
  - `{:error, %CalDAVEx.Error{}}` on failure

  ## Examples

      # Get all events
      {:ok, events} = CalDAVEx.list_events(client, calendar.url)

      # Get events in a date range
      {:ok, events} = CalDAVEx.list_events(client, calendar.url,
        from: ~U[2025-05-01 00:00:00Z],
        to: ~U[2025-05-31 23:59:59Z]
      )

      # Get future events
      {:ok, events} = CalDAVEx.list_events(client, calendar.url,
        from: DateTime.utc_now()
      )
  """
  def list_events(client, calendar_url, opts \\ []), do: Event.list(client, calendar_url, opts)

  @doc """
  Retrieves a single event by its URL.

  ## Parameters

  - `client` - The CalDAV client
  - `event_url` - The full URL of the event

  ## Returns

  - `{:ok, %CalDAVEx.Types.Event{}}` on success
  - `{:error, %CalDAVEx.Error{}}` on failure

  ## Examples

      {:ok, event} = CalDAVEx.get_event(client, "https://caldav.example.com/cal/event.ics")
      IO.inspect(event.calendar_data)
  """
  def get_event(client, event_url), do: Event.get(client, event_url)

  @doc """
  Creates a new event in a calendar.

  Note: This function is currently not fully implemented.

  ## Parameters

  - `client` - The CalDAV client
  - `calendar_url` - The URL of the calendar
  - `filename` - The filename for the event (e.g., "event.ics")
  - `ics_data` - The iCalendar data as a string
  """
  def create_event(client, calendar_url, filename, ics_data),
    do: Event.create(client, calendar_url, filename, ics_data)

  @doc """
  Updates an existing event.

  Note: This function is currently not fully implemented.

  ## Parameters

  - `client` - The CalDAV client
  - `event_url` - The URL of the event
  - `ics_data` - The updated iCalendar data
  - `etag` - Optional ETag for optimistic locking
  """
  def update_event(client, event_url, ics_data, etag \\ nil),
    do: Event.update(client, event_url, ics_data, etag)

  @doc """
  Deletes an event.

  Note: This function is currently not fully implemented.

  ## Parameters

  - `client` - The CalDAV client
  - `event_url` - The URL of the event
  - `etag` - Optional ETag for optimistic locking
  """
  def delete_event(client, event_url, etag \\ nil),
    do: Event.delete(client, event_url, etag)

  @doc """
  Converts a CalDAVEx.Error to a human-readable string.

  ## Parameters

  - `error` - A `%CalDAVEx.Error{}` struct

  ## Examples

      case CalDAVEx.list_events(client, calendar_url) do
        {:ok, events} -> events
        {:error, error} -> IO.puts(CalDAVEx.error_to_string(error))
      end
  """
  def error_to_string(error), do: Error.to_string(error)
end
