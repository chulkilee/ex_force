defmodule ExForce.API do
  require Logger

  @moduledoc """
  Simple wrapper for EXForce library for userpilot needs.
  """

  defp get_client(app_token) do
    case Salesforce.get_app(app_token) do
      %{client: client} ->
        {:ok, client}

      _ ->
        {:error,
         "Salesforce instance not initialized. Make sure you have setup your Salesforce for #{app_token}"}
    end
  end

  @spec register_new_app(%{
          :app_token => any(),
          :auth_url => any(),
          :client_id => any(),
          :client_secret => any(),
          optional(any()) => any()
        }) :: any()
  def register_new_app(
        %{
          app_token: _app_token,
          auth_url: _auth_url,
          client_id: _client_id,
          client_secret: _client_secret
        } = config
      ) do
    Salesforce.register_app_token(config)
  end

  @doc """

  Example:
  ExForce.API.get_object_unique_identifiers("NX-44d03690","Contact")
  """
  @spec get_object_unique_identifiers(
          %{:instance_url => binary(), optional(any()) => any()},
          binary()
        ) :: list()
  def get_object_unique_identifiers(app_token, object) do
    with {:ok, client} <- get_client(app_token) do
      {:ok, %{"fields" => fields}} = ExForce.describe_sobject(client, object)

      fields
      |> Enum.filter(fn field -> field["label"] == "Email" end)
      |> IO.inspect(limit: :infinity)
      |> Enum.filter(fn field -> field["unique"] == true end)
      |> Enum.map(fn field ->
        %{label: field["label"], name: field["name"], type: field["type"]}
      end)
    end
  end

  @doc """

  Example:
  ExForce.API.get_object_attributes("NX-44d03690","Contact")
  """
  def get_object_attributes(app_token, object) do
    with {:ok, client} <- get_client(app_token) do
      {:ok, %{"fields" => fields}} = ExForce.describe_sobject(client, object)

      fields
      |> Enum.map(fn field ->
        %{label: field["label"], name: field["name"], type: field["type"]}
      end)
    end
  end

  @doc """

  param_list is the list of parameters we want to retrieve from the object, eg: ["Name","Email"]

  Example:
  ExForce.API.get_contacts_paginated("NX-44d03690",["Name","Email"],10,0)
  """
  @spec get_contacts_paginated(
          binary(),
          charlist(),
          number(),
          number()
        ) :: list()
  def get_contacts_paginated(app_token, param_list, per_page, page) do
    with {:ok, client} <- get_client(app_token) do
      ExForce.query_stream(
        client,
        "SELECT #{Enum.join(param_list, " ,")} FROM Contact LIMIT #{per_page} OFFSET #{per_page * page}"
      )
      |> Stream.map(fn
        {:error,
         [
           %{
             "errorCode" => code,
             "message" => _message
           }
         ]} ->
          # re-auth
          code

        contact ->
          contact.data
          |> Map.put("id", contact.id)
      end)
      |> Enum.to_list()
    end
  end

  @doc """
  Example:
  ExForce.API.get_object_by_id("NX-44d03690","003Dp000005sjRJIAY","Contact")
  """
  @spec get_object_by_id(
          binary(),
          binary(),
          binary(),
          list()
        ) :: any()
  def get_object_by_id(app_token, id, sobject_name, fields \\ []) do
    with {:ok, client} <- get_client(app_token) do
      case ExForce.get_sobject(client, id, sobject_name, fields) do
        {:ok, %ExForce.SObject{data: data}} ->
          data

        {:error,
         [
           %{
             "errorCode" => code,
             "message" => _message
           }
         ]} ->
          # re-auth
          code
      end
    end
  end

  @doc """
  Example:
  ExForce.API.get_object_by_external_id("NX-44d03690","Customer","Userpilot_Id__c","userpilot456")
  """
  @spec get_object_by_external_id(
          binary(),
          binary(),
          binary(),
          binary()
        ) :: any()
  def get_object_by_external_id(
        app_token,
        sobject_name,
        field_name,
        field_value
      ) do
    with {:ok, client} <- get_client(app_token) do
      case ExForce.get_sobject_by_external_id(client, field_value, field_name, sobject_name) do
        {:ok, %ExForce.SObject{data: data}} ->
          data

        {:error,
         [
           %{
             "errorCode" => code,
             "message" => _message
           }
         ]} ->
          # re-auth
          code

        {:error, list} ->
          list
          |> List.last()
          |> String.split("/")
          |> List.last()
          |> (&get_object_by_id(app_token, &1, sobject_name)).()
      end
    end
  end
end
