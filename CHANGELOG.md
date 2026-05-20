# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.1.0]: https://github.com/swagner/caldav_ex/releases/tag/v0.1.0
