defmodule ExForce.Application do
  @moduledoc false

  use Application

  alias ExForce.Auth
  alias ExForce.OAuth.Config, as: OAuthConfig

  def start(_type, _args) do
    children = [
      {Auth, get_auth_arg()}
    ]

    opts = [strategy: :one_for_one, name: ExForce.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp get_auth_arg do
    oauth_config = %OAuthConfig{
      endpoint: get_config(:endpoint),
      client_id: get_config(:client_id),
      client_secret: get_config(:client_secret)
    }

    username = get_config(:username)
    password = to_string(get_config(:password)) <> to_string(get_config(:security_token))
    api_version = get_config(:api_version)

    {oauth_config, {username, password}, api_version}
  end

  defp get_config(key), do: Application.get_env(:ex_force, key)
end
