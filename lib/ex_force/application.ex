defmodule ExForce.Application do
  @moduledoc false

  use Application

  alias ExForce.Auth

  def start(_type, _args) do
    children = [
      {Auth, Application.get_env(:ex_force, ExForce.Auth)}
    ]

    opts = [strategy: :one_for_one, name: ExForce.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
