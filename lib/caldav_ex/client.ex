defmodule CalDAVEx.Client do
  @moduledoc """
  CalDAV client struct and initialization.
  """

  defstruct [:config]

  def new(config), do: %__MODULE__{config: config}
end
