defmodule CalDAVEx.XML do
  @moduledoc """
  XML parsing helpers for WebDAV/CalDAV `multistatus` responses.

  Uses `Saxy.SimpleForm` to parse the XML body, then walks the
  `D:response` elements to extract the properties commonly returned by
  CalDAV servers (`displayname`, `calendar-description`, `getctag`,
  `getetag`, `calendar-data`, and `resourcetype`). Only properties whose
  enclosing `D:propstat` has a `200 OK` status are returned; failed
  properties (`404`, `403`, etc.) are silently dropped.

  Relative `href` values are resolved against the caller-supplied
  `base_url` so downstream consumers always see absolute URLs.
  """

  alias CalDAVEx.Error

  @doc """
  Parses a WebDAV/CalDAV `D:multistatus` XML body.

  ## Parameters

    - `body` - the raw XML response body
    - `base_url` - the server base URL used to resolve relative `href` values

  ## Returns

    - `{:ok, [map]}` - a list of maps with keys `:href`, `:display_name`,
      `:description`, `:ctag`, `:etag`, `:calendar_data`, and `:is_calendar`
    - `{:error, %CalDAVEx.Error{type: :xml}}` if the body is not well-formed XML
  """
  def parse_multistatus(body, base_url) do
    case Saxy.SimpleForm.parse_string(body, cdata_as_characters: true) do
      {:ok, document} ->
        responses =
          document
          |> children_named("response")
          |> Enum.map(&parse_response(&1, base_url))

        {:ok, responses}

      {:error, error} ->
        {:error, Error.xml(Exception.message(error))}
    end
  end

  defp parse_response(response, base_url) do
    successful_props = get_successful_props(response)

    %{
      href: response |> child_text("href") |> absolute_url(base_url),
      display_name: prop_text(successful_props, "displayname"),
      description: prop_text(successful_props, "calendar-description"),
      ctag: prop_text(successful_props, "getctag"),
      etag: prop_text(successful_props, "getetag"),
      calendar_data: prop_text(successful_props, "calendar-data"),
      is_calendar: has_calendar_resourcetype?(successful_props)
    }
  end

  defp has_calendar_resourcetype?(props) do
    props
    |> Enum.find(&element_named?(&1, "resourcetype"))
    |> case do
      nil -> false
      resourcetype -> resourcetype |> children_named("calendar") |> Enum.any?()
    end
  end

  defp get_successful_props(response) do
    response
    |> children_named("propstat")
    |> Enum.filter(&successful_propstat?/1)
    |> Enum.flat_map(&get_prop_children/1)
  end

  defp successful_propstat?(propstat) do
    status = child_text(propstat, "status")
    status && String.contains?(status, "200 OK")
  end

  defp get_prop_children(propstat) do
    propstat
    |> children_named("prop")
    |> Enum.flat_map(fn {_, _, children} -> children end)
  end

  defp prop_text(props, name) do
    props
    |> Enum.find(&element_named?(&1, name))
    |> text()
  end

  defp children_named({_, _, children}, name) do
    Enum.filter(children, &element_named?(&1, name))
  end

  defp children_named(_, _name), do: []

  defp child_text(element, name) do
    element
    |> children_named(name)
    |> List.first()
    |> text()
  end

  defp element_named?({tag, _, _}, name), do: local_name(tag) == name
  defp element_named?(_, _name), do: false

  defp text({_, _, children}) do
    children
    |> Enum.map_join("", fn
      value when is_binary(value) -> value
      {:cdata, value} -> value
      _ -> ""
    end)
    |> String.trim()
    |> empty_to_nil()
  end

  defp text(_), do: nil

  defp local_name(tag) do
    tag
    |> String.split(":")
    |> List.last()
  end

  defp absolute_url(nil, _base_url), do: nil
  defp absolute_url("http" <> _ = url, _base_url), do: url

  defp absolute_url(path, base_url) do
    base_url
    |> URI.merge(path)
    |> URI.to_string()
  end

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value
end
