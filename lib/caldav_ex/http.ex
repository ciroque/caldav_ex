defmodule CalDAVEx.HTTP do
  @moduledoc """
  Low-level HTTP transport for CalDAV requests.

  Wraps `Req` to issue `GET`, `PUT`, `DELETE`, and the WebDAV/CalDAV
  extension methods (`PROPFIND`, `PROPPATCH`, `MKCALENDAR`, `REPORT`),
  injects standard headers (`User-Agent`, `Content-Type`, `Accept`) and
  the `Authorization` header produced by `CalDAVEx.Auth`, applies the
  client's configured `timeout_ms`, and normalizes results into either
  `{:ok, %{status, body, headers}}` or `{:error, %CalDAVEx.Error{}}`.
  """

  @typedoc """
  HTTP / WebDAV / CalDAV method.

  The convenience atoms `:propfind`, `:proppatch`, `:mkcalendar`, and
  `:report` are translated to their uppercase string equivalents before
  being passed to `Req`. Standard HTTP method atoms (`:get`, `:put`,
  `:delete`, ...) and raw string methods (e.g. `"PATCH"`) are passed
  through verbatim.
  """
  @type method :: atom() | String.t()

  @typedoc "Successful response payload."
  @type response :: %{
          status: non_neg_integer(),
          body: term(),
          headers: %{optional(binary()) => [binary()]}
        }

  @doc """
  Issues a single HTTP request against a CalDAV server.

  ## Parameters

    - `client` - a `%CalDAVEx.Client{}`
    - `method` - one of `:get`, `:put`, `:delete`, `:propfind`,
      `:proppatch`, `:mkcalendar`, `:report`, or any value accepted by `Req`
    - `url` - the absolute request URL
    - `headers` - additional request headers as `{name, value}` tuples
    - `body` - request body, or `nil` for methods that have no body

  ## Returns

    - `{:ok, %{status: non_neg_integer, body: term, headers: map}}` for 2xx responses
    - `{:error, %CalDAVEx.Error{type: :http}}` for non-2xx responses
    - `{:error, %CalDAVEx.Error{type: :transport}}` for connection/transport failures
  """
  @spec request(
          CalDAVEx.Client.t(),
          method(),
          String.t(),
          [{String.t(), String.t()}],
          iodata() | nil
        ) :: {:ok, response()} | {:error, CalDAVEx.Error.t()}
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
      {"user-agent", cfg.user_agent || CalDAVEx.Config.default_user_agent()},
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
