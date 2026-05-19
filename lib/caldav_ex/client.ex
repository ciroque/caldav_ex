defmodule CalDAVEx.Client do
  defstruct [:config]

  def new(config), do: %__MODULE__{config: config}
end