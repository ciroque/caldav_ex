defmodule CalDAVEx.Config do
  @moduledoc """
  Configuration for a `CalDAVEx.Client`.

  Holds the server base URL, authentication tuple, User-Agent string, and HTTP
  request timeout. Build configs with `new/2` and refine them with the
  `with_*` helpers. The top-level `CalDAVEx` module exposes thin wrappers
  around these functions for the common case.
  """

  defstruct [:base_url, :auth, :user_agent, timeout_ms: 10_000]

  @doc """
  Builds a new configuration.

  The trailing slash on `base_url` is stripped so that downstream URL joining
  is unambiguous.

  ## Parameters

    - `base_url` - the CalDAV server base URL (must be a binary)
    - `auth` - an authentication tuple from `CalDAVEx.basic_auth/2`,
      `CalDAVEx.bearer_auth/1`, or `CalDAVEx.no_auth/0`

  ## Examples

      CalDAVEx.Config.new(
        "https://caldav.example.com/",
        CalDAVEx.basic_auth("user", "pass")
      )
  """
  def new(base_url, auth) when is_binary(base_url) do
    %__MODULE__{
      base_url: String.trim_trailing(base_url, "/"),
      auth: auth,
      user_agent: default_user_agent()
    }
  end

  @doc """
  Returns the library's default `User-Agent` string.

  Derived at runtime from the loaded application spec
  (`:application.get_key(:caldav_ex, :vsn)`), so it always matches the
  released package version. Falls back to `"caldav_ex"` if the
  application spec is not loaded (e.g. during compilation of the
  library itself).

  ## Returns

    - the default User-Agent string (e.g. `"caldav_ex/0.2.1"`)
  """
  def default_user_agent do
    case :application.get_key(:caldav_ex, :vsn) do
      {:ok, vsn} -> "caldav_ex/" <> List.to_string(vsn)
      :undefined -> "caldav_ex"
    end
  end

  @doc """
  Returns a copy of `cfg` with the given User-Agent string.

  ## Parameters

    - `cfg` - an existing `%CalDAVEx.Config{}`
    - `ua` - the User-Agent string to send on every request

  ## Returns

    - the updated `%CalDAVEx.Config{}` struct

  ## Examples

      config |> CalDAVEx.Config.with_user_agent("MyApp/1.0")
  """
  def with_user_agent(%__MODULE__{} = cfg, ua), do: %{cfg | user_agent: ua}

  @doc """
  Returns a copy of `cfg` with the given request timeout in milliseconds.

  The timeout is passed to the underlying HTTP client as `receive_timeout`.

  ## Parameters

    - `cfg` - an existing `%CalDAVEx.Config{}`
    - `ms` - timeout in milliseconds (must be a non-negative integer)

  ## Returns

    - the updated `%CalDAVEx.Config{}` struct

  ## Examples

      config |> CalDAVEx.Config.with_timeout(30_000)
  """
  def with_timeout(%__MODULE__{} = cfg, ms) when is_integer(ms) and ms >= 0,
    do: %{cfg | timeout_ms: ms}
end
