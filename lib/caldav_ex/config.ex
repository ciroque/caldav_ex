defmodule CalDAVEx.Config do
  defstruct [:base_url, :auth, user_agent: "caldav_ex/0.1.0", timeout_ms: 10_000]

  def new(base_url, auth) when is_binary(base_url) do
    %__MODULE__{
      base_url: String.trim_trailing(base_url, "/"),
      auth: auth
    }
  end

  def with_user_agent(%__MODULE__{} = cfg, ua), do: %{cfg | user_agent: ua}
  def with_timeout(%__MODULE__{} = cfg, ms) when is_integer(ms), do: %{cfg | timeout_ms: ms}
end