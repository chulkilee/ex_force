defmodule ExForce do
  @moduledoc """
  Simple wrapper for Salesforce REST API.
  """

  alias ExForce.{AuthRequest, Client, Config}

  @type config_or_func :: Config.t() | (-> Config.t())

  @doc """
  Authenticate with username and password.

  See [Understanding the Username-Password OAuth Authentication Flow](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/intro_understanding_username_password_oauth_flow.htm)
  """
  @spec authenticate(AuthRequest.t()) :: {:ok, Config.t()} | {:error, any}
  def authenticate(request = %AuthRequest{}) do
    form = [
      grant_type: "password",
      client_id: request.client_id,
      client_secret: request.client_secret,
      username: request.username,
      password: request.password <> to_string(request.security_token)
    ]

    url = request.endpoint <> "/services/oauth2/token"

    case Client.request!(:post, url, {:form, form}) do
      {
        200,
        %{
          "access_token" => access_token,
          "instance_url" => instance_url,
          "issued_at" => issued_at
        }
      } ->
        {
          :ok,
          %Config{
            access_token: access_token,
            instance_url: instance_url,
            issued_at: DateTime.from_unix!(String.to_integer(issued_at), :millisecond),
            api_version: request.api_version
          }
        }
      {400, err} ->
        {:error, err}
    end
  end

  @doc """
  Lists available REST API versions at an instance.

  See [Versions](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_versions.htm)
  """
  @spec versions(String.t()) :: {:ok, list(map)} | {:error, any}
  def versions(instance_url) do
    case Client.request!(:get, instance_url <> "/services/data") do
      {200, raw} -> {:ok, raw}
      {_, raw} -> {:error, raw}
    end
  end

  @doc """
  Lists available resources for the specific API version.

  See [Resources by Version](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_discoveryresource.htm)
  """
  @spec resources(String.t(), config_or_func) :: {:ok, map} | {:error, any}
  def resources(version, config) do
    case request_get("/services/data/v#{version}", config) do
      {200, raw} -> {:ok, raw}
      {_, raw} -> {:error, raw}
    end
  end

  defp request_get(path, query \\ [], config), do: request(:get, path, query, "", config)

  defp request(method, path, query, body, config)

  defp request(method, path, query, body, config) when is_function(config, 0),
    do: request(method, path, query, body, config.())

  defp request(method, path, query, body, config = %Config{access_token: access_token}) do
    Client.request!(method, build_url(path, query, config), body, [
      {"authorization", "Bearer " <> access_token}
    ])
  end

  defp build_url(path, [], %Config{instance_url: instance_url}), do: instance_url <> path

  defp build_url(path, query, config = %Config{}),
    do: build_url(path <> "?" <> URI.encode_query(query), [], config)
end
