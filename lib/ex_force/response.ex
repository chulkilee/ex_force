defmodule ExForce.Response do
  @moduledoc """
  Represents the result of a HTTP request.
  """

  @type t :: %__MODULE__{
          status_code: integer(),
          headers: %{optional(String.t()) => [String.t()]},
          body: any
        }

  defstruct [
    :status_code,
    :headers,
    :body
  ]
end
