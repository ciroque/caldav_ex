defmodule CalDAVEx.Types do
  @moduledoc """
  Type definitions for CalDAV resources.
  """

  defmodule DiscoveryInfo do
    @moduledoc """
    Discovery information for a CalDAV server.

    Contains URLs discovered during the CalDAV discovery process.
    """

    @typedoc """
    Discovery information struct.

    ## Fields

    - `principal_url` - The URL of the authenticated user's principal
    - `calendar_home_set_url` - The URL of the user's calendar collection
    """
    @type t :: %__MODULE__{
            principal_url: String.t(),
            calendar_home_set_url: String.t()
          }

    defstruct [:principal_url, :calendar_home_set_url]
  end

  defmodule Calendar do
    @moduledoc """
    Represents a CalDAV calendar.

    Contains metadata about a calendar collection.
    """

    @typedoc """
    Calendar struct.

    ## Fields

    - `url` - The full URL of the calendar
    - `display_name` - Human-readable name of the calendar
    - `description` - Optional description of the calendar
    - `ctag` - Calendar collection tag for sync purposes
    - `is_calendar` - Whether this resource is a calendar (has C:calendar resourcetype)
    """
    @type t :: %__MODULE__{
            url: String.t(),
            display_name: String.t() | nil,
            description: String.t() | nil,
            ctag: String.t() | nil,
            is_calendar: boolean()
          }

    defstruct [:url, :display_name, :description, :ctag, :is_calendar]
  end

  defmodule Event do
    @moduledoc """
    Represents a CalDAV event.

    Contains both the raw iCalendar data and parsed event properties.
    """

    @typedoc """
    Event struct.

    ## Fields

    - `href` - The full URL of the event resource
    - `etag` - Entity tag for optimistic locking
    - `calendar_data` - Raw iCalendar (ICS) data for the entire CalDAV resource.
      When a single resource contains multiple `VEVENT` components (e.g.
      a recurring master plus `RECURRENCE-ID` overrides, or expanded
      occurrences from `<C:expand>`), every `Event` derived from that
      resource shares the same `calendar_data`, `href`, and `etag`. This
      mirrors CalDAV semantics: the resource — not the occurrence — is
      the unit of mutation. To update, `PUT` the shared `href` with the
      full `calendar_data` (modified as needed). To delete, `DELETE` the
      shared `href`; `calendar_data` is not sent or required.
    - `content_type` - MIME type of the calendar data
    - `summary` - Event title/summary
    - `dtstart` - Start date/time (DateTime for timed events, Date for all-day events)
    - `dtend` - End date/time (DateTime for timed events, Date for all-day events)
    - `uid` - Unique identifier for the event
    - `description` - Detailed description of the event
    - `location` - Location of the event
    - `status` - Event status (e.g., "CONFIRMED", "TENTATIVE", "CANCELLED")
    - `rrule` - Recurrence rule (RRULE) as a string
    - `organizer` - Event organizer
    - `attendees` - List of event attendees
    """
    @type t :: %__MODULE__{
            href: String.t(),
            etag: String.t() | nil,
            calendar_data: String.t() | nil,
            content_type: String.t() | nil,
            summary: String.t() | nil,
            dtstart: DateTime.t() | Date.t() | nil,
            dtend: DateTime.t() | Date.t() | nil,
            uid: String.t() | nil,
            description: String.t() | nil,
            location: String.t() | nil,
            status: String.t() | nil,
            rrule: String.t() | nil,
            organizer: String.t() | nil,
            attendees: list(String.t())
          }

    defstruct [
      :href,
      :etag,
      :calendar_data,
      :content_type,
      :summary,
      :dtstart,
      :dtend,
      :uid,
      :description,
      :location,
      :status,
      :rrule,
      :organizer,
      attendees: []
    ]
  end
end
