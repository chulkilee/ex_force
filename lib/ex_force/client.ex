defmodule ExForce.Client do
  @moduledoc """
  HTTP Client for Salesforce REST API.

  - Ask for body in gzip and handle gzipped response body
  - Send request body as JSON
  - Decode response body as JSON
  """

  alias HTTPoison.Response

  @default_headers [
    {"accept-encoding", "gzip"},
    {"accept", "application/json"},
    {"user-agent", "ex_force"}
  ]

  @type response :: {number, any}

  @doc """
  Issues an HTTP request with the given method to the given url.
  """
  def request!(method, url, body \\ "", headers \\ [], options \\ [])

  def request!(method, url, body, headers, options) when is_map(body) or is_list(body),
    do: request!(method, url, Poison.encode!(body), headers, options)

  def request!(method, url, body, headers, options) do
    method
    |> HTTPoison.request!(url, body, build_headers(headers, body), options)
    |> lowercase_headers()
    |> gunzip()
    |> decode_json()
    |> transform_response()
  end

  defp build_headers(headers, ""), do: headers ++ @default_headers

  defp build_headers(headers, _body),
    do: headers ++ @default_headers ++ [{"content-type", "application/json"}]

  defp lowercase_headers(resp = %Response{headers: headers}) do
    headers = for {k, v} <- headers, do: {String.downcase(k), v}
    %Response{resp | headers: headers}
  end

  defp gunzip(resp = %Response{body: ""}), do: resp

  defp gunzip(resp = %Response{body: body}) do
    case get_header(resp, "content-encoding") do
      ["gzip"] -> %Response{resp | body: :zlib.gunzip(body)}
      [] -> resp
    end
  end

  defp decode_json(resp = %Response{body: body}) when byte_size(body) == 0, do: resp

  defp decode_json(resp = %Response{body: body}) do
    case get_header(resp, "content-type") do
      ["application/json" <> _] -> %Response{resp | body: Poison.decode!(body)}
      [] -> resp
    end
  end

  defp transform_response(%Response{body: body, status_code: status}), do: {status, body}

  defp get_header(%Response{headers: headers}, key) do
    for {k, v} <- headers, k == key, do: v
  end
end
