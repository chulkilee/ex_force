defmodule ExForce.OAuth.Response do
  @moduledoc """
  Represents the result of a successful OAuth response.
  """

  @type access_token :: String.t()
  @type refresh_token :: String.t()

  @type t :: %__MODULE__{
          token_type: String.t(),
          instance_url: String.t(),
          id: String.t(),
          issued_at: DateTime.t(),
          signature: String.t(),
          access_token: String.t(),
          refresh_token: refresh_token
                         | nil,
          scope: String.t()
                 | nil
        }

  defstruct [
    :token_type,
    :instance_url,
    :id,
    :issued_at,
    :signature,
    :access_token,
    :refresh_token,
    :scope
  ]
end
