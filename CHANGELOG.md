# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.4] - 2026-05-21

### Fixed

- Fixed iCalendar DTSTART/DTEND parsing to handle TZID parameters (e.g., `DTSTART;TZID=America/Los_Angeles:20260120T160000`)
- Events with timezone-aware datetime properties now correctly parse and convert to UTC
- Added proper handling for DST transitions:
  - Fall-back (ambiguous times): chooses first occurrence
  - Spring-forward (gap times): chooses time after the gap
- Events from Apple Calendar and other iCalendar clients with TZID parameters now parse correctly
- **CRITICAL:** Fixed timezone database dependency - library now works without consumer config
  - All datetime operations use explicit `Tz.TimeZoneDatabase` parameter
  - Applies to TZID parsing, UTC conversion, and CalDAV time-range formatting
  - Previously required consumers to configure `:elixir, :time_zone_database` in their app
  - Library now works out-of-the-box when added as a dependency
- Fixed RFC5545 compliance: TZID parameter now correctly parsed regardless of position or case
  - Handles multiple parameters in any order (e.g., `DTSTART;VALUE=DATE-TIME;TZID=...`)
  - Case-insensitive property name matching per RFC5545 specification
  - Supports quoted TZID parameter values (e.g., `TZID="America/New_York"`)

### Changed

- Improved test coverage with comprehensive test cases for TZID parsing, including:
  - Timezone conversion for various timezones
  - DST transition handling (fall-back ambiguous and spring-forward gap times)
  - Error handling for invalid timezones and malformed datetimes
  - Backward compatibility with UTC and DATE formats
  - RFC5545 compliance (multiple parameters, quoted values, case-insensitivity)
- Performance optimization: precompiled TZID extraction regexes at module compile-time
  - Eliminates repeated regex compilation overhead when processing multiple events
  - Zero runtime cost for regex compilation
- Stricter datetime validation: regex now enforces exact iCalendar DATE-TIME format (YYYYMMDDTHHmmss)
  - Rejects malformed datetime values early (e.g., extra digits, missing separators)
  - Prevents partial matches on invalid input
- RFC5545 line unfolding: properly handles continuation lines in iCalendar data
  - Unfolds lines that begin with space or tab per RFC5545 section 3.1
  - Ensures TZID extraction works with folded properties and XML-indented content
- Improved error handling: replaced bang functions with explicit error handling
  - Uses `DateTime.shift_zone/3` instead of `shift_zone!/2` with blanket rescue
  - Explicit handling of `{:ok, dt}` and `{:error, reason}` for better debugging
  - Separated timezone resolution logic for clarity

## [0.1.0] - 2026-05-19

### Added

- Initial release
- CalDAV discovery (current-user-principal and calendar-home-set)
- Calendar listing with display name, description, and ctag
- Event listing with time-range filtering
- Single event retrieval by URL
- Robust XML parsing using Saxy
- iCalendar parsing via ical library
- Support for both timed and all-day events
- Basic and no-auth authentication methods
- Comprehensive test suite with Bypass HTTP mocking

### Features

- `CalDAVEx.discover/1` - Discover principal and calendar home set
- `CalDAVEx.list_calendars/2` - List all calendars
- `CalDAVEx.list_events/3` - List events with optional time filtering
- `CalDAVEx.get_event/2` - Retrieve a single event by URL
- `CalDAVEx.new_config/2` - Create client configuration
- `CalDAVEx.new_client/1` - Create CalDAV client
- `CalDAVEx.basic_auth/2` - Basic authentication
- `CalDAVEx.no_auth/0` - No authentication

[0.1.0]: https://github.com/ciroque/caldav_ex/releases/tag/v0.1.0
[0.1.4]: https://github.com/ciroque/caldav_ex/releases/tag/v0.1.4
