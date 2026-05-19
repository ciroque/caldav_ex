defmodule CalDAVEx.XML do
  alias CalDAVEx.Error

  def parse_multistatus(body, base_url) do
    with {:ok, document} <- Saxy.SimpleForm.parse_string(body, cdata_as_characters: true) do
      responses =
        document
        |> children_named("response")
        |> Enum.map(&parse_response(&1, base_url))

      {:ok, responses}
    else
      {:error, error} -> {:error, Error.xml(Exception.message(error))}
    end
  end

  defp parse_response(response, base_url) do
    %{
      href: response |> child_text("href") |> absolute_url(base_url),
      display_name: response |> descendant_text("displayname"),
      description: response |> descendant_text("calendar-description"),
      ctag: response |> descendant_text("getctag"),
      etag: response |> descendant_text("getetag"),
      calendar_data: response |> descendant_text("calendar-data")
    }
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

  defp descendant_text(element, name) do
    element
    |> descendants()
    |> Enum.find(&element_named?(&1, name))
    |> text()
  end

  defp descendants({_, _, children}) do
    Enum.flat_map(children, fn
      {_, _, _} = child -> [child | descendants(child)]
      _ -> []
    end)
  end

  defp descendants(_), do: []

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
