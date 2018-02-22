defmodule ExForce do
  @moduledoc """
  Simple wrapper for Salesforce REST API.

  ## Usage

  ```elixir
  oauth_config = %ExForce.OAuth.Config{
    endpoint: "https://login.salesforce.com",
    client_id: "...",
    client_secret: "..."
  }

  {:ok, config} =
    :password
    |> ExForce.OAuth.get_token({"username", "password"}, oauth_config)
    |> ExForce.Config.from("40.0")

  names =
    "SELECT Name FROM Account"
    |> ExForce.query_stream(config)
    |> Enum.map(&(Map.fetch!(&1.data, "Name")))
  ```

  Or you can use `ExForce.Auth` to provide default config for functions taking `ExForce.Config`.
  See `ExForce.Auth` for configuration details.

  ```elixir
  {:ok, %ExForce.QueryResult{records: [%ExForce.SObject{data: %{"counts" => counts }}]}} =
    ExForce.query("SELECT COUNT(Id) counts FROM Account")
  ```
  """

  alias ExForce.{Auth, Client, Config, QueryResult, Response, SObject}

  @type sobject_id :: String.t()
  @type sobject_name :: String.t()
  @type field_name :: String.t()
  @type soql :: String.t()
  @type query_id :: String.t()
  @type config_or_func :: Config.t() | (() -> Config.t())

  @doc """
  Get default config from `ExForce.Auth`
  """
  @spec default_config() :: Config.t() | no_return
  def default_config, do: Auth.get!()

  @doc """
  Lists available REST API versions at an instance.

  See [Versions](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_versions.htm)
  """
  @spec versions(String.t()) :: {:ok, list(map)} | {:error, any}
  def versions(instance_url) do
    case Client.request!(:get, instance_url <> "/services/data") do
      %Response{status_code: 200, body: raw} -> {:ok, raw}
      %Response{body: raw} -> {:error, raw}
    end
  end

  @doc """
  Lists available resources for the specific API version.

  See [Resources by Version](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_discoveryresource.htm)
  """
  @spec resources(String.t(), config_or_func) :: {:ok, map} | {:error, any}
  def resources(version, config \\ default_config()) do
    case request_get("/services/data/v#{version}", config) do
      %Response{status_code: 200, body: raw} -> {:ok, raw}
      %Response{body: raw} -> {:error, raw}
    end
  end

  @doc """
  Lists the available objects

  See [Describe Global](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_describeGlobal.htm)
  """
  @spec describe_global(config_or_func) :: {:ok, map} | {:error, any}
  def describe_global(config \\ default_config()) do
    case request_get("/sobjects", config) do
      %Response{status_code: 200, body: raw} -> {:ok, raw}
      %Response{body: raw} -> {:error, raw}
    end
  end

  @doc """
  Retrieves extended metadata for the specified SObject.

  See [SObject Describe](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_describe.htm)
  """
  @spec describe_sobject(sobject_name, config_or_func) :: {:ok, map} | {:error, any}
  def describe_sobject(name, config \\ default_config()) do
    case request_get("/sobjects/#{name}/describe", config) do
      %Response{status_code: 200, body: raw} -> {:ok, raw}
      %Response{body: raw} -> {:error, raw}
    end
  end

  @doc """
  Retrieves basic metadata for the specific SObject.

  See [SObject Basic Information](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_basic_info.htm)
  """
  @spec basic_info(sobject_name, config_or_func) :: {:ok, map} | {:error, any}
  def basic_info(name, config \\ default_config()) do
    case request_get("/sobjects/#{name}", config) do
      %Response{status_code: 200, body: raw = %{"recentItems" => recent_items}} ->
        {:ok, Map.put(raw, "recentItems", Enum.map(recent_items, &SObject.build/1))}

      %Response{body: raw} ->
        {:error, raw}
    end
  end

  @doc """
  Retrieves a SObject by ID.

  See [SObject Rows](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_retrieve.htm)
  """
  @spec get_sobject(sobject_id, sobject_name, list, config_or_func) ::
          {:ok, SObject.t()} | {:error, any}
  def get_sobject(id, name, fields, config \\ default_config()),
    do: do_get_sobject("/sobjects/#{name}/#{id}", fields, config)

  @doc """
  Retrieves a SObject based on the value of a specified extneral ID field.

  See [SObject Rows by External ID](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_upsert.htm)
  """
  @spec get_sobject_by_external_id(any, field_name, sobject_name, config_or_func) ::
          {:ok, SObject.t()} | {:error, any}
  def get_sobject_by_external_id(
        field_value,
        field_name,
        sobject_name,
        config \\ default_config()
      ),
      do:
        do_get_sobject(
          "/sobjects/#{sobject_name}/#{field_name}/#{URI.encode(field_value)}",
          config
        )

  @doc """
  Retrieves a SObject by relationship field.

  See [SObject Relationships](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_relationships.htm)
  """
  @spec get_sobject_by_relationship(sobject_id, sobject_name, field_name, config_or_func) ::
          {:ok, SObject.t()} | {:error, any}
  def get_sobject_by_relationship(
        id,
        sobject_name,
        field_name,
        fields,
        config \\ default_config()
      ),
      do: do_get_sobject("/sobjects/#{sobject_name}/#{id}/#{field_name}", fields, config)

  defp do_get_sobject(path, fields \\ [], config) do
    case request_get(path, build_fields_query(fields), config) do
      %Response{status_code: 200, body: raw} -> {:ok, SObject.build(raw)}
      %Response{body: raw} -> {:error, raw}
    end
  end

  defp build_fields_query([]), do: []
  defp build_fields_query(fields), do: [fields: Enum.join(fields, ",")]

  @doc """
  Updates a SObject.

  See [SObject Rows](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_retrieve.htm)
  """
  @spec update_sobject(sobject_id, sobject_name, map, config_or_func) :: :ok | {:error, any}
  def update_sobject(id, name, attrs, config \\ default_config()) do
    case request_patch("/sobjects/#{name}/#{id}", Poison.encode!(attrs), config) do
      %Response{status_code: 204, body: ""} -> :ok
      %Response{body: raw} -> {:error, raw}
    end
  end

  @doc """
  Creates a SObject.

  See [SObject Rows](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_basic_info.htm)
  """
  @spec create_sobject(sobject_name, map, config_or_func) :: :ok | {:error, any}
  def create_sobject(name, attrs, config \\ default_config()) do
    case request_post("/sobjects/#{name}/", Poison.encode!(attrs), config) do
      %Response{status_code: 201, body: %{"id" => id, "success" => true}} -> {:ok, id}
      %Response{body: raw} -> {:error, raw}
    end
  end

  @doc """
  Deletes a SObject.

  [SObject Rows](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_retrieve.htm)
  """
  @spec delete_sobject(sobject_id, sobject_name, config_or_func) :: :ok | {:error, any}
  def delete_sobject(id, name, config \\ default_config()) do
    case request_delete("/sobjects/#{name}/#{id}", config) do
      %Response{status_code: 204, body: ""} -> :ok
      %Response{status_code: 404, body: errors} -> {:error, errors}
    end
  end

  @doc """
  Excute the SOQL query and get the result of it.

  [Query](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_query.htm)
  """
  @spec query(soql, config_or_func) :: {:ok, QueryResult.t()} | {:error, any}
  def query(soql, config \\ default_config()) do
    case request_get("/query", [q: soql], config) do
      %Response{status_code: 200, body: raw} -> {:ok, build_result_set(raw)}
      %Response{body: raw} -> {:error, raw}
    end
  end

  @spec query_stream(soql, config_or_func) :: Enumerable.t()
  def query_stream(soql, config \\ default_config()),
    do: start_query_stream(&query/2, soql, config)

  @doc """
  Retrieve additional query results for the specified query ID.

  [Query](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_query.htm)
  """
  @spec query_retrieve(query_id | String.t(), config_or_func) ::
          {:ok, QueryResult.t()} | {:error, any}
  def query_retrieve(query_id_or_url, config \\ default_config()) do
    path =
      if full_path?(query_id_or_url) do
        query_id_or_url
      else
        "/query/#{query_id_or_url}"
      end

    case request_get(path, config) do
      %Response{status_code: 200, body: raw} -> {:ok, build_result_set(raw)}
      %Response{body: raw} -> {:error, raw}
    end
  end

  @doc """
  Excute the SOQL query and get the result of it, including deleted or archived objects.

  [QueryAll](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_queryall.htm)
  """
  @spec query_all(soql, config_or_func) :: {:ok, QueryResult.t()} | {:error, any}
  def query_all(soql, config \\ default_config()) do
    case request_get("/queryAll", [q: soql], config) do
      %Response{status_code: 200, body: raw} -> {:ok, build_result_set(raw)}
      %Response{body: raw} -> {:error, raw}
    end
  end

  @spec query_all_stream(soql, config_or_func) :: Enumerable.t()
  def query_all_stream(soql, config \\ default_config()),
    do: start_query_stream(&query_all/2, soql, config)

  defp build_result_set(resp = %{"records" => records, "totalSize" => total_size}) do
    result_set =
      case resp do
        %{"done" => true} ->
          %QueryResult{done: true}

        %{"done" => false, "nextRecordsUrl" => next_records_url} ->
          %QueryResult{done: false, next_records_url: next_records_url}
      end

    %QueryResult{
      result_set
      | total_size: total_size,
        records: records |> Enum.map(&SObject.build/1)
    }
  end

  @spec start_query_stream(
          (soql, config_or_func -> {:ok, QueryResult.t()} | any),
          soql,
          config_or_func
        ) :: Enumerable.t()
  defp start_query_stream(func, soql, config) do
    {:ok, qr} = func.(soql, config)
    stream_query_result(qr, config)
  end

  @doc """
  Returns `Enumerable.t` from the `QueryResult`.
  """
  @spec stream_query_result(QueryResult.t(), config_or_func) :: Enumerable.t()
  def stream_query_result(qr = %QueryResult{}, config) do
    Stream.unfold({qr, config}, &stream_unfold/1)
  end

  defp stream_unfold({qr = %QueryResult{records: [h | tail]}, config}),
    do: {h, {%QueryResult{qr | records: tail}, config}}

  defp stream_unfold(
         {
           %QueryResult{records: [], done: false, next_records_url: next_records_url},
           config
         }
       ) do
    {:ok, qr = %QueryResult{records: [h | tail]}} = query_retrieve(next_records_url, config)
    {h, {%QueryResult{qr | records: tail}, config}}
  end

  defp stream_unfold({%QueryResult{records: [], done: true}, _config}), do: nil

  defp request_get(path, query \\ [], config), do: request(:get, path, query, "", config)

  defp request_post(path, body, config), do: request(:post, path, [], body, config)

  defp request_patch(path, body, config), do: request(:patch, path, [], body, config)

  defp request_delete(path, query \\ [], config), do: request(:delete, path, query, "", config)

  defp request(method, path, query, body, config)

  defp request(method, path, query, body, config) when is_function(config, 0),
    do: request(method, path, query, body, config.())

  defp request(method, path, query, body, config = %Config{access_token: access_token}) do
    Client.request!(method, build_url(path, query, config), body, [
      {"authorization", "Bearer " <> access_token}
    ])
  end

  defp full_path?(path), do: String.starts_with?(path, "/services/data/v")

  defp build_url(path, [], %Config{instance_url: instance_url, api_version: api_version}) do
    if full_path?(path) do
      instance_url <> path
    else
      instance_url <> "/services/data/v" <> api_version <> path
    end
  end

  defp build_url(path, query, config = %Config{}),
    do: build_url(path <> "?" <> URI.encode_query(query), [], config)
end
