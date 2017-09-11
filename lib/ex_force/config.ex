defmodule ExForce.Config do
  @moduledoc """
  Holds authentication and endpoint information.
  """

  @type t :: %__MODULE__{
          access_token: String.t(),
          api_version: String.t(),
          instance_url: String.t(),
          issued_at: DateTime.t()
        }

  defstruct [:access_token, :api_version, :instance_url, :issued_at]
end
