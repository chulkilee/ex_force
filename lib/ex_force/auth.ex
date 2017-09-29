defmodule ExForce.Auth do
  @moduledoc """
  `GenServer` to authenticate and return `ExForce.Config`.
  """

  use GenServer

  alias ExForce.Config
  alias ExForce.OAuth
  alias ExForce.OAuth.Config, as: OAuthConfig

  @type username :: String.t()
  @type password :: String.t()
  @type api_version :: String.t()

  @type args :: {OAuthConfig.t(), {username, password}, api_version}

  defmodule State do
    @moduledoc false

    alias ExForce.Config
    alias ExForce.OAuth.Config, as: OAuthConfig

    @type t :: %__MODULE__{
            oauth_config: OAuthConfig.t(),
            username: String.t(),
            password: String.t(),
            api_version: String.t(),
            current: Config.t()
            | nil
          }

    defstruct [:oauth_config, :username, :password, :api_version, :current]
  end

  @doc """
  Starts a `GenServer` process using the module as its name.
  """
  @spec start_link(args) :: GenServer.on_start()
  def start_link(args), do: start_link(args, name: __MODULE__)

  @doc """
  Starts a `GenServer` process with given options.
  """
  @spec start_link(args, GenServer.options()) :: GenServer.on_start()
  def start_link(args, options) do
    GenServer.start_link(__MODULE__, args, options)
  end

  @impl true
  def init({oauth_config = %OAuthConfig{}, {username, password}, api_version}) do
    state = %State{
      oauth_config: oauth_config,
      username: username,
      password: password,
      api_version: api_version,
      current: nil
    }

    {:ok, state}
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
  def handle_call(:authenticate, _from, state = %State{current: current})
      when not is_nil(current), do: {:reply, {:ok, current}, state}

  @impl true
  def handle_call(
        :authenticate,
        _from,
        state = %State{
          oauth_config: oauth_config,
          username: username,
          password: password,
          api_version: api_version
        }
      ) do
    case :password
         |> OAuth.get_token({username, password}, oauth_config)
         |> Config.from(api_version) do
      {:ok, config} ->
        {:reply, {:ok, config}, %State{state | current: config}}

      {:error, error} ->
        {:reply, {:error, error}, state}
    end
  end
end
