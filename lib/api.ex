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
          :app_token => String.t(),
          :auth_url => String.t(),
          :client_id => String.t(),
          :client_secret => any(),
          :redirect_uri => String.t(),
          :code => String.t(),
          :code_verifier => String.t(),
          optional(any()) => any()
        }) :: any()
  def register_new_app(config) do
    Salesforce.register_app_token(config)
  end

  @spec refresh_app_client(%{
          :app_token => String.t(),
          :auth_url => String.t(),
          :client_id => String.t(),
          :client_secret => any(),
          :refresh_token => String.t()
        }) :: any()
  def refresh_app_client(config) do
    Salesforce.refresh_app_token(config)
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
        %{title: field["label"], id: field["name"], type: field["type"]}
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
        %{title: field["label"], id: field["name"], type: field["type"]}
      end)
    end
  end

  @doc """

  param_list is the list of parameters we want to retrieve from the object, eg: ["Name","Email"]

  Example:
  ExForce.API.get_objects_paginated("NX-44d03690","Contact",["Name","Email"],10,0)
  """
  @spec get_objects_paginated(
          binary(),
          binary(),
          charlist(),
          number(),
          number()
        ) :: list()
  def get_objects_paginated(app_token, object, param_list, per_page, page)
      when object in ["Contact", "Lead", "Account"] do
    with {:ok, client} <- get_client(app_token) do
      param_list = ["Id" | Enum.reject(param_list, &is_nil/1)]

      ExForce.query_stream(
        client,
        "SELECT #{Enum.join(param_list, " ,")} FROM #{object} LIMIT #{per_page} OFFSET #{per_page * page}"
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

        result ->
          result.data
          |> Map.put("Id", result.id)
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
          {:ok, data}

        {:error,
         [
           %{
             "errorCode" => code,
             "message" => _message
           }
         ]} ->
          # re-auth
          {:error, code}
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
          binary(),
          list()
        ) :: any()
  def get_object_by_external_id(
        app_token,
        sobject_name,
        field_name,
        field_value,
        fields
      ) do
    with {:ok, client} <- get_client(app_token) do
      case ExForce.get_sobject_by_external_id(
             client,
             field_value,
             field_name,
             sobject_name,
             fields
           ) do
        {:ok, %ExForce.SObject{data: data}} ->
          {:ok, data}

        {:error,
         [
           %{
             "errorCode" => code,
             "message" => _message
           }
         ]} ->
          # re-auth
          {:error, code}

        {:error, list} ->
          list
          |> List.last()
          |> String.split("/")
          |> List.last()
          |> (&get_object_by_id(app_token, &1, sobject_name)).()
      end
    end
  end

  @doc """
  Example:
  ExForce.API.search_object_by_field("NX-44d03690","Customer","Userpilot_Id__c","userpilot456")
  """
  @spec search_object_by_field(
          binary(),
          binary(),
          binary(),
          binary(),
          list()
        ) :: any()
  def search_object_by_field(
        app_token,
        sobject_name,
        field_name,
        field_value,
        fields
      )
      when fields != [] do
    with {:ok, client} <- get_client(app_token) do
      case ExForce.query(
             client,
             "SELECT #{Enum.join(fields, " ,")} FROM #{sobject_name} WHERE #{field_name} = '#{field_value}' LIMIT 1"
           ) do
        {:ok, %ExForce.QueryResult{done: true, records: list}} when list == [] ->
          {:error, "NOT_FOUND"}

        {:ok, %ExForce.QueryResult{done: true, records: list}} ->
          record = List.first(list)
          {:ok, Map.put(record.data, "Id", record.id)}

        {:error,
         [
           %{
             "errorCode" => code,
             "message" => _message
           }
         ]} ->
          {:error, code}
      end
    end
  end

  def search_object_by_field(
        app_token,
        sobject_name,
        field_name,
        field_value,
        _fields
      ) do
    with {:ok, client} <- get_client(app_token) do
      case ExForce.query(
             client,
             "SELECT FIELDS(STANDARD) FROM #{sobject_name} WHERE #{field_name} = '#{field_value}' LIMIT 1"
           ) do
        {:ok, %ExForce.QueryResult{done: true, records: list}} when list == [] ->
          {:error, "NOT_FOUND"}

        {:ok, %ExForce.QueryResult{done: true, records: list}} ->
          record = List.first(list)
          {:ok, Map.put(record.data, "Id", record.id)}

        {:error,
         [
           %{
             "errorCode" => code,
             "message" => _message
           }
         ]} ->
          {:error, code}
      end
    end
  end

  @spec create_apex_class(binary(), binary(), binary()) :: {:error, any()} | {:ok, binary()}
  def create_apex_class(
        app_token,
        class_name,
        class_body
      ) do
    with {:ok, client} <- get_client(app_token),
         {:ok, %{body: %{"id" => id}}} <-
           ExForce.create_sobject(client, "ApexClass", %{
             Name: class_name,
             Body: class_body
           }) do
      {:ok, id}
    else
      {:error, body} ->
        {:error, body}
    end
  end

  @spec create_apex_trigger(binary(), binary(), binary(), binary()) ::
          {:error, any()} | {:ok, binary()}
  def create_apex_trigger(
        app_token,
        trigger_name,
        trigger_body,
        trigger_object
      ) do
    with {:ok, client} <- get_client(app_token),
         {:ok, %{body: %{"id" => id}}} <-
           ExForce.create_sobject(client, "ApexTrigger", %{
             Name: trigger_name,
             TableEnumOrId: trigger_object,
             Body: trigger_body,
             Status: "Active"
           }) do
      {:ok, id}
    else
      {:error, body} ->
        {:error, body}
    end
  end

  @spec create_custom_event(binary(), binary(), map()) ::
          {:error, any()} | {:ok, binary()}
  def create_custom_event(
        app_token,
        custom_event_schema_name,
        body
      ) do
    with {:ok, client} <- get_client(app_token),
         {:ok, %{body: body, time: time}} <-
           ExForce.create_sobject(client, custom_event_schema_name, body) do
      {:ok, Map.put(body, :time, time)}
    else
      {:error, body} ->
        {:error, body}
    end
  end

  @spec delete_apex_class(any(), any()) :: :ok | {:error, any()}
  def delete_apex_class(
        app_token,
        class_id
      ) do
    with {:ok, client} <- get_client(app_token) do
      ExForce.delete_sobject(client, class_id, "ApexClass")
    end
  end

  @spec delete_apex_trigger(any(), any()) :: :ok | {:error, any()}
  def delete_apex_trigger(
        app_token,
        trigger_id
      ) do
    with {:ok, client} <- get_client(app_token) do
      ExForce.delete_sobject(client, trigger_id, "ApexTrigger")
    end
  end

  @spec create_custom_object_schema(String.t(), any()) ::
          {:error, any()} | {:ok, binary()}
  def create_custom_object_schema(app_token, schema) do
    with {:ok, client} <- get_client(app_token),
         %{config: %{access_token: access_token}} = Salesforce.get_app(app_token) do
      ExForce.create_custom_object_schema(client, access_token, schema)
    end
  end
end
