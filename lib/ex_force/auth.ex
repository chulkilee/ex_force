defmodule ExForce.Auth do
  @moduledoc """
  `GenServer` to authenticate and return `ExForce.Config`.

  ## Configuration

  You can pass all configuration via Mix.

  ```elixir
  config :ex_force, ExForce,Auth
    endpoint: "https://login.salesforce.com",
    client_id: "...",
    client_secret: "...",
    username: "user@example.com",
    password: "...",
    security_token: "...",
    api_version: "40.0"
  ```

  Or you can load all configuration from system environment variables (using `System.get_env/1`).

  ```elixir
  config :ex_force, ExForce,Auth
    load_from_system_env: true
  ```

  In this case, following system environment variables will be used.

  - `SALESFORCE_ENDPOINT`
  - `SALESFORCE_CLIENT_ID`
  - `SALESFORCE_CLIENT_SECRET`
  - `SALESFORCE_USERNAME`
  - `SALESFORCE_PASSWORD`
  - `SALESFORCE_SECURITY_TOKEN`
  - `SALESFORCE_API_VERSION`
  """

  use GenServer

  alias ExForce.Config
  alias ExForce.OAuth
  alias ExForce.OAuth.Config, as: OAuthConfig

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
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(args), do: start_link(args, name: __MODULE__)

  @doc """
  Starts a `GenServer` process with given options.
  """
  @spec start_link(keyword(), GenServer.options()) :: GenServer.on_start()
  def start_link(args, options) do
    GenServer.start_link(__MODULE__, args, options)
  end

  @impl true
  def init(args) do
    {
      :ok,
      args
      |> get_config()
      |> build_state()
    }
  end

  defp get_config(config) do
    if config[:load_from_system_env] do
      [
        endpoint: System.get_env("SALESFORCE_ENDPOINT"),
        client_id: System.get_env("SALESFORCE_CLIENT_ID"),
        client_secret: System.get_env("SALESFORCE_CLIENT_SECRET"),
        username: System.get_env("SALESFORCE_USERNAME"),
        password: System.get_env("SALESFORCE_PASSWORD"),
        security_token: System.get_env("SALESFORCE_SECURITY_TOKEN"),
        api_version: System.get_env("SALESFORCE_API_VERSION")
      ]
    else
      config
    end
  end

  defp build_state(config) do
    %State{
      oauth_config: %OAuthConfig{
        endpoint: config[:endpoint],
        client_id: config[:client_id],
        client_secret: config[:client_secret]
      },
      username: config[:username],
      password: to_string(config[:password]) <> to_string(config[:security_token]),
      api_version: config[:api_version],
      current: nil
    }
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
      when not is_nil(current),
      do: {:reply, {:ok, current}, state}

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
