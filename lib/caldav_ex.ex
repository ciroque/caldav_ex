defmodule CalDAVEx do
  alias CalDAVEx.{Config, Client, Discovery, Calendar, Event, Error}

  # Auth
  def no_auth, do: :no_auth
  def basic_auth(username, password), do: {:basic, username, password}
  def bearer_auth(token), do: {:bearer, token}

  # Config
  def new_config(base_url, auth), do: Config.new(base_url, auth)
  def with_user_agent(config, ua), do: Config.with_user_agent(config, ua)
  def with_timeout(config, ms), do: Config.with_timeout(config, ms)

  # Client
  def new_client(config), do: Client.new(config)

  # Discovery
  def discover(client), do: Discovery.discover(client)

  # Calendars
  def list_calendars(client, discovery_info), do: Calendar.list(client, discovery_info)

  # Events
  def list_events(client, calendar_url), do: Event.list(client, calendar_url)
  def get_event(client, event_url), do: Event.get(client, event_url)

  def create_event(client, calendar_url, filename, ics_data),
      do: Event.create(client, calendar_url, filename, ics_data)

  def update_event(client, event_url, ics_data, etag \\ nil),
      do: Event.update(client, event_url, ics_data, etag)

  def delete_event(client, event_url, etag \\ nil),
      do: Event.delete(client, event_url, etag)

  def error_to_string(error), do: Error.to_string(error)
end