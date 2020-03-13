defmodule ExForce.Response do
  @moduledoc """
  Represents an ExForce API response.
  """

  @type param() :: binary() | [{binary() | atom(), param()}]
  @type t :: %__MODULE__{
    body: any(),
    headers: [{binary(), binary()}],
    method: :head | :get | :delete | :trace | :options | :post | :put | :patch,
    opts: [any()],
    query: [{binary() | atom(), param()}],
    status: integer() | nil,
    url: binary(),
  }

  defstruct [
    :body,
    :headers,
    :method,
    :opts,
    :query,
    :status,
    :url,
  ]
end
