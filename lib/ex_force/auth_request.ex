defmodule ExForce.AuthRequest do
  @moduledoc """
  Holds information to perform authentication.
  """

  @type t :: %__MODULE__{
          endpoint: String.t(),
          client_id: String.t(),
          client_secret: String.t(),
          username: String.t(),
          password: String.t(),
          security_token: String.t()
          | nil,
          api_version: String.t()
        }

  defstruct [
    :endpoint,
    :client_id,
    :client_secret,
    :username,
    :password,
    :security_token,
    :api_version
  ]
end
