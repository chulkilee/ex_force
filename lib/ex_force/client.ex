defmodule ExForce.Client do
  @moduledoc """
  HTTP Client for Salesforce REST API using Tesla.

  ## Adapter

  To use different Tesla adapter, set it via Mix configuration.

  ```elixir
  config :tesla, ExForce.Client, adapter: Tesla.Adapter.Hackney
  ```
  """

  use Tesla

  @type t :: Tesla.Client.t()
end
