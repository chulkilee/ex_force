defmodule ExForce.OAuth do
  @moduledoc """
  Handles OAuth2

  ## Grant Types

  - `authorization_code`: [Understanding the Web Server OAuth Authentication Flow](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/intro_understanding_web_server_oauth_flow.htm)
  - `password`: [Understanding the Username-Password OAuth Authentication Flow](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/intro_understanding_username_password_oauth_flow.htm)
  - `token`: [Understanding the User-Agent OAuth Authentication Flow](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/intro_understanding_user_agent_oauth_flow.htm)
  - `refresh_token`: [Understanding the OAuth Refresh Token Process](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/intro_understanding_refresh_token_oauth.htm)
  """

  alias ExForce.{
    Client,
    OAuthResponse,
    Request,
    Response
  }

  @type username :: String.t()
  @type password :: String.t()
  @type code :: String.t()
  @type redirect_uri :: String.t()

  defdelegate build_client(instance_url), to: Client, as: :build_oauth_client
  defdelegate build_client(instance_url, opts), to: Client, as: :build_oauth_client

  @doc """
  Returns the authorize url based on the configuration.

  ### `authorization_code`

  ```elixir
  ExForce.OAuth.authorize_url(
    "https://login.salesforce.com",
    response_type: "code",
    client_id: "client-id",
    redirect_uri: "https://example.com/callback"
  )
  ```

  ### `token`

  ```elixir
  ExForce.OAuth.authorize_url(
    "https://login.salesforce.com",
    response_type: "token",
    client_id: "client-id",
    redirect_uri: "https://example.com/callback"
  )
  ```
  """

  @spec authorize_url(String.t(), Enum.t()) :: String.t()
  def authorize_url(endpoint, enum) do
    endpoint <> "/services/oauth2/authorize?" <> URI.encode_query(enum)
  end

  @doc """
  Fetches an `ExForce.OAuthResponse` struct by making a request to the token endpoint.

  ### `authorization_code`

  ```elixir
  ExForce.OAuth.get_token(
    "https://login.salesforce.com",
    grant_type: "authorization_code",
    code: "code",
    redirect_uri: "https://example.com/callback",
    client_id: "client_id",
    client_secret: "client_secret"
  )
  ```

  ### `password`

  ```elixir
  ExForce.OAuth.get_token(
    "https://login.salesforce.com",
    grant_type: "password",
    client_id: "client_id",
    client_secret: "client_secret",
    username: "username",
    password: "password" <> "security_token"
  )
  ```

  ### `refresh_token`

    ```elixir
  ExForce.OAuth.get_token(
    "https://login.salesforce.com",
    grant_type: "refresh_token",
    client_id: "client_id",
    client_secret: "client_secret",
    refresh_token: "refresh_token"
  )
  ```

  ### `jwt_token`

    ```elixir
  ExForce.OAuth.get_token(
    "https://login.salesforce.com",
    grant_type: "jwt",
    username: "username",
    client_id: "client_id",
    jwt_key: "jwt_key"
  )
  ```

  """

  @spec get_token(ExForce.Client.t() | String.t(), list) ::
          {:ok, OAuthResponse.t()} | {:error, :invalid_signature | term}

  def get_token(url, payload) when is_binary(url) do
    url
    |> build_client
    |> then(
      &if Keyword.fetch!(payload, :grant_type) == "jwt" do
        get_token_jwt(&1, url, payload)
      else
        get_token(&1, payload)
      end
    )
  end

  def get_token(client, payload) do
    client_secret = Keyword.fetch!(payload, :client_secret)

    case Client.request(client, %Request{
           method: :post,
           url: "/services/oauth2/token",
           body: payload
         }) do
      {:ok,
       %Response{
         status: 200,
         body:
           map = %{
             "token_type" => token_type,
             "instance_url" => instance_url,
             "id" => id,
             "signature" => signature,
             "issued_at" => issued_at,
             "access_token" => access_token
           }
       }} ->
        verify_signature(
          %OAuthResponse{
            token_type: token_type,
            instance_url: instance_url,
            id: id,
            issued_at: issued_at |> String.to_integer() |> DateTime.from_unix!(:millisecond),
            signature: signature,
            access_token: access_token,
            refresh_token: Map.get(map, "refresh_token"),
            scope: Map.get(map, "scope")
          },
          client_secret
        )

      {:ok, %Response{body: body}} ->
        {:error, body}

      {:error, _} = other ->
        other
    end
  end

  def get_token_jwt(client, url, payload) do
    case Client.request(client, %Request{
           method: :post,
           url: "/services/oauth2/token",
           body: create_jwt_payload(url, payload)
         }) do
      {:ok,
       %Response{
         status: 200,
         body: %{
           "token_type" => token_type,
           "instance_url" => instance_url,
           "id" => id,
           "access_token" => access_token,
           "scope" => scope
         }
       }} ->
        {:ok,
         %OAuthResponse{
           token_type: token_type,
           instance_url: instance_url,
           id: id,
           access_token: access_token,
           scope: scope
         }}

      {:ok, %Response{body: body}} ->
        {:error, body}

      {:error, _} = other ->
        other
    end
  end

  defp verify_signature(
         %OAuthResponse{id: id, issued_at: issued_at, signature: signature} = resp,
         client_secret
       ) do
    if signature == calculate_signature(id, issued_at, client_secret) do
      {:ok, resp}
    else
      {:error, :invalid_signature}
    end
  end

  defp calculate_signature(id, issued_at, client_secret) do
    issued_at_raw =
      issued_at
      |> DateTime.to_unix(:millisecond)
      |> Integer.to_string()

    hmac_fun(client_secret, id <> issued_at_raw)
    |> Base.encode64()
  end

  # :crypto.mac/4 was defined in OTP 22 and :crypto.hmac/3 was removed in OTP 24,
  # this ensures backwards compatibility between erlang versions
  if Code.ensure_loaded?(:crypto) and function_exported?(:crypto, :mac, 4) do
    defp hmac_fun(key, data), do: :crypto.mac(:hmac, :sha256, key, data)
  else
    defp hmac_fun(key, data), do: :crypto.hmac(:sha256, key, data)
  end

  defp create_jwt_payload(url, payload) do
    IO.inspect("in create jwt payload")
    key = %{"pem" => Keyword.fetch!(payload, :jwt_key)}
    signer = Joken.Signer.create("RS256", key)

    claims = %{
      "iss" => Keyword.fetch!(payload, :client_id),
      "aud" => url,
      "sub" => Keyword.fetch!(payload, :username),
      "iat" => System.os_time(:second),
      "exp" => System.os_time(:second) + 180
    }

    {:ok, token, _claims} = Joken.encode_and_sign(claims, signer)

    [
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: token
    ]
  end
end
