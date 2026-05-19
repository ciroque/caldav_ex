defmodule CalDAVEx.Types do
  defmodule DiscoveryInfo do
    defstruct [:principal_url, :calendar_home_set_url]
  end

  defmodule Calendar do
    defstruct [:url, :display_name, :description, :ctag]
  end

  defmodule Event do
    defstruct [:href, :etag, :calendar_data, :content_type]
  end
end