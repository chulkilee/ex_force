defmodule ExForce.Auth do
  @moduledoc """
  `GenServer` to authenticate and return `ExForce.Config`.
  """

  use GenServer

  alias ExForce.{AuthRequest, Config}

  @doc """
  Starts a `GenServer` process using the module as its name.
  """
  @spec start_link({AuthRequest.t()}) :: GenServer.on_start()
  def start_link(args), do: start_link(args, name: __MODULE__)

  @doc """
  Starts a `GenServer` process with given options.
  """
  @spec start_link({AuthRequest.t()}, GenServer.options()) :: GenServer.on_start()
  def start_link(args, options) do
    GenServer.start_link(__MODULE__, args, options)
  end

  @impl true
  def init({auth_request = %AuthRequest{}}) do
    {:ok, {auth_request}}
  end

  @doc """
  Get the cached authentication or perform the authentication.
  """
  @spec get(GenServer.server(), timeout) :: {:ok, Config.t()} | {:error, any}
  def get(server \\ __MODULE__, timeout \\ 5000),
    do: GenServer.call(server, :authenticate, timeout)

  @doc """
  Get the cached authentication or perform the authentication; erroring out if failed.
  """
  @spec get!(GenServer.server(), timeout) :: Config.t() | no_return
  def get!(server \\ __MODULE__, timeout \\ 5000) do
    {:ok, config} = get(server, timeout)
    config
  end

  @impl true
  def handle_call(:authenticate, _from, {auth_request, existing}),
    do: {:reply, {:ok, existing}, {auth_request, existing}}

  @impl true
  def handle_call(:authenticate, _from, {auth_request}) do
    case ExForce.authenticate(auth_request) do
      {:ok, config} ->
        {:reply, {:ok, config}, {auth_request, config}}
      {:error, error} ->
        {:reply, {:error, error}, {auth_request}}
    end
  end
end
