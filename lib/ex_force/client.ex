defmodule ExForce.Client do
  @moduledoc """
  HTTP Client for Salesforce REST API.

  - Ask for body in gzip and handle gzipped response body
  - Send request body as JSON
  - Decode response body as JSON
  """

  alias HTTPoison.Response, as: RawResponse
  alias ExForce.Response

  @default_headers [
    {"accept-encoding", "gzip"},
    {"accept", "application/json"},
    {"user-agent", "ex_force"}
  ]

  @type response :: Response.t()

  @doc """
  Issues an HTTP request with the given method to the given url.
  """
  def request!(method, url, body \\ "", headers \\ [], options \\ [])

  def request!(method, url, body, headers, options) when is_map(body) or is_list(body),
    do: request!(method, url, Poison.encode!(body), headers, options)

  def request!(method, url, body, headers, options) do
    method
    |> HTTPoison.request!(url, body, build_headers(headers, body), options)
    |> unpack_raw_response()
    |> transform_headers()
    |> gunzip()
    |> decode_json()
    |> build_response()
  end

  defp build_headers(headers, ""), do: headers ++ @default_headers

  defp build_headers(headers, _body),
    do: headers ++ @default_headers ++ [{"content-type", "application/json"}]

  defp unpack_raw_response(%RawResponse{status_code: status_code, headers: headers, body: body}),
    do: {status_code, headers, body}

  defp transform_headers({status_code, headers, body}) do
    headers = Enum.group_by(headers, fn {k, _} -> String.downcase(k) end, fn {_, v} -> v end)
    {status_code, headers, body}
  end

  defp gunzip(resp = {_status_code, _headers, ""}), do: resp

  defp gunzip(resp = {status_code, headers, body}) do
    case Map.get(headers, "content-encoding") do
      ["gzip"] -> {status_code, headers, :zlib.gunzip(body)}
      nil -> resp
    end
  end

  defp decode_json(resp = {_status_code, _headers, body}) when byte_size(body) == 0, do: resp

  defp decode_json(resp = {status_code, headers, body}) do
    case Map.get(headers, "content-type") do
      ["application/json" <> _] -> {status_code, headers, Poison.decode!(body)}
      nil -> resp
    end
  end

  defp build_response({status_code, headers, body}),
    do: %Response{body: body, headers: headers, status_code: status_code}
end
