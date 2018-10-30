defmodule ExForce.Client do
  @moduledoc """
  HTTP Client for Salesforce REST API using Tesla.
  """

  @default_api_version "42.0"
  @default_user_agent "ex_force"

  @type t :: Tesla.t()

  defdelegate request(client, opts \\ []), to: Tesla
  defdelegate get(client, url, opts \\ []), to: Tesla
  defdelegate post(client, url, body, opts \\ []), to: Tesla
  defdelegate put(client, url, body, opts \\ []), to: Tesla

  @doc """
  Build a client.

  Options

  - `:headers`: set additional headers; default: `[{"user-agent", "#{@default_user_agent}"}]`
  - `:api_version`: use the given api_version; default: `"#{@default_api_version}"`
  - `:adapter`: see `Tesla.client/2`
  """
  def new(instance_url_or_map, opts \\ [headers: [{"user-agent", @default_user_agent}]])

  def new(%{instance_url: instance_url, access_token: access_token}, opts) do
    with headers <- Keyword.get(opts, :headers, []),
         new_headers <- [{"authorization", "Bearer " <> access_token} | headers],
         new_opts <- Keyword.put(opts, :headers, new_headers) do
      new(instance_url, new_opts)
    end
  end

  def new(instance_url, opts) when is_binary(instance_url) do
    Tesla.client(
      [
        {ExForce.TeslaMiddleware,
         {instance_url, Keyword.get(opts, :api_version, @default_api_version)}},
        {Tesla.Middleware.Compression, format: "gzip"},
        {Tesla.Middleware.JSON, engine: Jason},
        {Tesla.Middleware.Headers, Keyword.get(opts, :headers, [])}
      ],
      Keyword.get(opts, :adapter)
    )
  end
end
