defmodule Salesforce do
  @moduledoc """
  This genserver for salesforce that holds integrations config and clients for per app token
  """

  defmodule State do
    defstruct [
      :applications
    ]

    @type t :: %__MODULE__{
            applications: map()
          }
  end

  use GenServer

  @refresh_token_interval_ms 2 * 60 * 60 * 1000

  #
  # External API
  #

  def register_app_token(app) do
    GenServer.call(__MODULE__, {:register_app, app})
  end

  def get_app(app_token) do
    GenServer.call(__MODULE__, {:get_app, app_token})
  end

  # Client

  def start_link(callback_fun) do
    GenServer.start_link(__MODULE__, callback_fun, name: __MODULE__)
  end

  def child_spec(callback_fun) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [callback_fun]}}
  end

  # Server (callbacks)

  @impl true
  def init(callback_fun) when is_function(callback_fun, 0) do
    applications =
      callback_fun.()
      |> Enum.reduce(%{}, fn app, applications ->
        with {:ok, client} <- init_client(app.config) do
          Map.put(applications, String.to_atom(app.app_token), %{
            config: app.config,
            client: client
          })
        end
      end)

    {:ok, %State{applications: applications}}
  end

  @impl true
  def handle_info({:refresh_token, app_token}, %State{applications: applications} = state) do
    app = Map.get(applications, String.to_atom(app_token))

    case init_client(app.config) do
      {:ok, client} ->
        applications =
          Map.put(applications, String.to_atom(app.app_token), %{
            config: app.config,
            client: client
          })

        {:noreply, %State{state | applications: applications}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:register_app, app}, _from, %State{applications: applications} = state) do
    case init_client(app) do
      {:ok, client} ->
        applications =
          Map.put(applications, String.to_atom(app.app_token), %{
            config: app,
            client: client
          })

        {:reply, :ok, %State{state | applications: applications}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:get_app, app_token}, _from, %State{applications: applications} = state) do
    app = Map.get(applications, String.to_atom(app_token), nil)

    {:reply, app, state}
  end

  # the initializing of the genserver do authenticate with salesforce and build the client, then it stores the client in ets table,
  # Authentication Response Example:
  # {:ok,
  # %ExForce.OAuthResponse{
  #   access_token: "00DDp0000018Wr2!AQEAQDV4NO.YPKFZSFV38KxZAnDxVZX6wWV67isrYI124_3tbvJsFAnZwuS05hY0ElkIl_0rSvOBM2dc454I9DkPwPm7COBp",
  #   id: "https://login.salesforce.com/id/00DDp0000018Wr2MAE/005Dp000002NCZXIA4",
  #   instance_url: "https://userpilot-dev-ed.develop.my.salesforce.com",
  #   issued_at: ~U[2023-11-07 13:19:11.832Z],
  #   refresh_token: nil,
  #   scope: "api",
  #   signature: "*/*",
  #   token_type: "Bearer"
  # }}

  defp init_client(
         %{
           app_token: app_token,
           auth_url: auth_url,
           client_id: client_id,
           client_secret: client_secret
         } = _config
       ) do
    with {:ok, %{instance_url: instance_url} = oauth_response} <-
           ExForce.OAuth.get_token(auth_url,
             grant_type: "client_credentials",
             client_id: client_id,
             client_secret: client_secret
           ) do
      {:ok, version_maps} = ExForce.versions(instance_url)
      latest_version = version_maps |> Enum.map(&Map.fetch!(&1, "version")) |> List.last()

      client = ExForce.build_client(oauth_response, api_version: latest_version)
      Process.send_after(self(), {:refresh_token, app_token}, @refresh_token_interval_ms)
      {:ok, client}
    end
  end
end
