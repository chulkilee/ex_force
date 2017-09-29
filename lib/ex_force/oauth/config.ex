defmodule ExForce.OAuth.Config do
  @moduledoc """
  Holds OAuth2 configuration.
  """

  @type t :: %__MODULE__{
          endpoint: String.t(),
          client_id: String.t(),
          client_secret: String.t()
        }
  defstruct [:endpoint, :client_id, :client_secret]
end
