defmodule CalDAVEx.HTTP do
  alias CalDAVEx.Config

  def request(client, method, url, headers \\ [], body \\ nil) do
    cfg = client.config

    opts = [
      headers: build_headers(cfg, headers),
      body: body,
      method: build_method(method),
      url: url,
      receive_timeout: cfg.timeout_ms
    ]

    case Req.request(opts) do
      {:ok, %Req.Response{status: status, body: body} = resp} when status in 200..299 ->
        {:ok, %{status: status, body: body, headers: resp.headers}}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, CalDAVEx.Error.http(status, body)}

      {:error, error} ->
        {:error, CalDAVEx.Error.transport(inspect(error))}
    end
  end

  defp build_headers(cfg, extra) do
    auth_headers = CalDAVEx.Auth.to_headers(cfg.auth)

    [
      {"user-agent", cfg.user_agent},
      {"content-type", "application/xml; charset=utf-8"},
      {"accept", "application/xml"}
      | auth_headers ++ extra
    ]
  end

  defp build_method(:propfind), do: "PROPFIND"
  defp build_method(:proppatch), do: "PROPPATCH"
  defp build_method(:mkcalendar), do: "MKCALENDAR"
  defp build_method(:report), do: "REPORT"
  defp build_method(method), do: method
end
