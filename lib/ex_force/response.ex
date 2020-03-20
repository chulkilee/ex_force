defmodule ExForce.Response do
  @moduledoc """
  Represents an API response.
  """

  @type t :: %__MODULE__{
          body: any(),
          headers: [{binary(), binary()}],
          method: :head | :get | :delete | :trace | :options | :post | :put | :patch,
          opts: [any()],
          query: [{binary() | atom(), binary()}],
          status: integer() | nil,
          url: binary()
        }

  defstruct [
    :body,
    :headers,
    :method,
    :opts,
    :query,
    :status,
    :url
  ]
end
