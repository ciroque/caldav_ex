defmodule CalDAVEx.Discovery do
  alias CalDAVEx.{HTTP, Types.DiscoveryInfo, Error}

  def discover(client) do
    with {:ok, principal} <- find_principal(client),
         {:ok, home_set} <- find_calendar_home_set(client, principal) do
      {:ok,
       %DiscoveryInfo{
         principal_url: principal,
         calendar_home_set_url: home_set
       }}
    end
  end

  defp find_principal(client) do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <D:propfind xmlns:D="DAV:">
      <D:prop><D:current-user-principal/></D:prop>
    </D:propfind>
    """

    case HTTP.request(client, :propfind, client.config.base_url, [{"depth", "0"}], xml) do
      {:ok, %{body: body}} ->
        parse_href_property(body, client.config.base_url, "current-user-principal")

      error ->
        error
    end
  end

  defp find_calendar_home_set(client, principal) do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <D:propfind xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
      <D:prop><C:calendar-home-set/></D:prop>
    </D:propfind>
    """

    case HTTP.request(client, :propfind, principal, [{"depth", "0"}], xml) do
      {:ok, %{body: body}} ->
        parse_href_property(body, client.config.base_url, "calendar-home-set")

      error ->
        error
    end
  end

  defp parse_href_property(body, base_url, property) do
    with {:ok, document} <- Saxy.SimpleForm.parse_string(body, cdata_as_characters: true),
         {:ok, href} <- find_property_href(document, property) do
      {:ok, absolute_url(href, base_url)}
    else
      {:error, %Saxy.ParseError{} = error} -> {:error, Error.xml(Exception.message(error))}
      {:error, reason} -> {:error, Error.protocol(reason)}
    end
  end

  defp find_property_href(document, property) do
    case find_descendant(document, property) do
      nil -> {:error, "Could not find #{property}"}
      element -> element |> child_text("href") |> href_result(property)
    end
  end

  defp href_result(nil, property), do: {:error, "Could not find href for #{property}"}
  defp href_result(href, _property), do: {:ok, href}

  defp find_descendant({_, _, children} = element, name) do
    if element_named?(element, name) do
      element
    else
      Enum.find_value(children, &find_descendant(&1, name))
    end
  end

  defp find_descendant(_, _name), do: nil

  defp child_text({_, _, children}, name) do
    children
    |> Enum.find(&element_named?(&1, name))
    |> text()
  end

  defp child_text(_, _name), do: nil

  defp element_named?({tag, _, _}, name), do: local_name(tag) == name
  defp element_named?(_, _name), do: false

  defp text({_, _, children}) do
    children
    |> Enum.map(fn
      value when is_binary(value) -> value
      {:cdata, value} -> value
      _ -> ""
    end)
    |> Enum.join("")
    |> String.trim()
    |> empty_to_nil()
  end

  defp text(_), do: nil

  defp local_name(tag) do
    tag
    |> String.split(":")
    |> List.last()
  end

  defp absolute_url("http" <> _ = url, _base_url), do: url

  defp absolute_url(path, base_url) do
    base_url
    |> URI.merge(path)
    |> URI.to_string()
  end

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value
end
