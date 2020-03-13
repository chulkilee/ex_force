defmodule ExForce.Client.Tesla do
  @moduledoc """
  HTTP Client for Salesforce REST API using Tesla.

  ## Adapter

  To use different Tesla adapter, set it via Mix configuration.

  ```elixir
  config :tesla, ExForce.Client.Tesla, adapter: Tesla.Adapter.Hackney
  ```
  """

  @behaviour ExForce.Client

  alias ExForce.{
    Request,
    Response,
  }

  @default_api_version "42.0"
  @default_user_agent "ex_force"

  @doc """
  Returns Tesla client for ExForce functions

  Options

  - `:headers`: set additional headers; default: `[{"user-agent", "#{@default_user_agent}"}]`
  - `:api_version`: use the given api_version; default: `"#{@default_api_version}"`
  - `:adapter`: use the given adapter with custom opts; default: `nil`, which causes Tesla to use the default adapter or the one set in config.
  """
  @impl ExForce.Client
  def build_client(instance_url_or_map, opts \\ [headers: [{"user-agent", @default_user_agent}]])

  def build_client(%{instance_url: instance_url, access_token: access_token}, opts) do
    with headers <- Keyword.get(opts, :headers, []),
         new_headers <- [{"authorization", "Bearer " <> access_token} | headers],
         new_opts <- Keyword.put(opts, :headers, new_headers) do
      build_client(instance_url, new_opts)
    end
  end

  def build_client(instance_url, opts) when is_binary(instance_url) do
    Tesla.client([
      {ExForce.Client.Tesla.Middleware,
       {instance_url, Keyword.get(opts, :api_version, @default_api_version)}},
      {Tesla.Middleware.Compression, format: "gzip"},
      {Tesla.Middleware.JSON, engine: Jason},
      {Tesla.Middleware.Headers, Keyword.get(opts, :headers, [])}
    ], Keyword.get(opts, :adapter))
  end

  @doc """
  Returns client for ExForce.OAuth functions

  ### Options

  - `:user_agent`
  """
  @impl ExForce.Client
  def build_oauth_client(url, opts \\ [headers: [{"user-agent", @default_user_agent}]]) do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, url},
      {Tesla.Middleware.Compression, format: "gzip"},
      Tesla.Middleware.FormUrlencoded,
      {Tesla.Middleware.DecodeJson, engine: Jason},
      {Tesla.Middleware.Headers, Keyword.get(opts, :headers, [])}
    ], Keyword.get(opts, :adapter))
  end

  @doc """
  Sends a request to Salesforce
  """
  @impl ExForce.Client
  def request(%Tesla.Client{} = client, %Request{} = request) do
    client
    |> Tesla.request(cast_tesla_request(request))
    |> cast_response()
  end

  defp cast_tesla_request(%Request{} = request) do
    request
    |> convert_struct(Tesla.Env)
    |> Map.to_list()
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp convert_struct(%_struct{} = fields, new_struct),
    do: struct(new_struct, Map.from_struct(fields))

  defp cast_response({:ok, %Tesla.Env{} = response}),
    do: {:ok, convert_struct(response, Response)}

  defp cast_response({:error, error}), do: {:error, error}
end
