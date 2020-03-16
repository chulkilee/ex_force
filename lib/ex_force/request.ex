defmodule ExForce.Request do
  @moduledoc """
  Represents an ExForce API request.
  """

  @type param() :: binary() | [{binary() | atom(), param()}]
  @type t :: %__MODULE__{
          body: any(),
          headers: [{binary(), binary()}],
          method: :head | :get | :delete | :trace | :options | :post | :put | :patch,
          opts: [any()],
          query: [{binary() | atom(), param()}],
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
