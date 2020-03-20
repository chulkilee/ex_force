defmodule ExForce.Request do
  @moduledoc """
  Represents an API request.
  """

  @type t :: %__MODULE__{
          body: any(),
          headers: [{binary(), binary()}],
          method: :head | :get | :delete | :trace | :options | :post | :put | :patch,
          opts: [any()],
          query: [{binary() | atom(), binary()}],
          url: binary()
        }

  defstruct [
    :body,
    :headers,
    :method,
    :opts,
    :query,
    :url
  ]
end
