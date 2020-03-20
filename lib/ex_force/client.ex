defmodule ExForce.Client do
  @moduledoc """
  HTTP Client for Salesforce REST API

  ## Adapter

  Defaults to ExForce.Client.Tesla. To use your own adapter, set it via Mix configuration.

  ```elixir
  config :ex_force, client: ClientMock
  ```
  """

  alias ExForce.{
    Request,
    Response
  }

  @type t :: any()
  @type opts :: Keyword.t()
  @type instance_url :: map() | String.t()

  @callback build_client(instance_url) :: t()
  @callback build_client(instance_url, opts) :: t()

  @callback build_oauth_client(instance_url) :: t()
  @callback build_oauth_client(instance_url, opts) :: t()

  @callback request(t(), Request.t()) :: {:ok, Response.t()} | {:error, any()}

  def build_client(instance_url), do: adapter().build_client(instance_url)
  def build_client(instance_url, opts), do: adapter().build_client(instance_url, opts)

  def build_oauth_client(instance_url), do: adapter().build_oauth_client(instance_url)
  def build_oauth_client(instance_url, opts), do: adapter().build_oauth_client(instance_url, opts)

  def request(client, request), do: adapter().request(client, request)

  defp adapter, do: Application.get_env(:ex_force, :client, ExForce.Client.Tesla)
end
