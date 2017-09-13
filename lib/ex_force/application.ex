defmodule ExForce.Application do
  @moduledoc false

  use Application

  alias ExForce.{Auth, AuthRequest}

  def start(_type, _args) do
    children = [
      {Auth, {auth_request()}}
    ]

    opts = [strategy: :one_for_one, name: ExForce.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp auth_request do
    fields =
      [
        :endpoint,
        :client_id,
        :client_secret,
        :username,
        :password,
        :security_token,
        :api_version
      ]
      |> Enum.map(fn k -> {k, Application.get_env(:ex_force, k)} end)

    struct!(%AuthRequest{}, fields)
  end
end
