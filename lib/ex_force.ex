defmodule ExForce do
  @moduledoc """
  Simple wrapper for Salesforce REST API.
  """

  alias ExForce.{AuthRequest, Client, Config}

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
end
