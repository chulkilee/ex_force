defmodule ExForceTest do
  use ExUnit.Case, async: true
  doctest(ExForce)

  alias ExForce.{Config, QueryResult, SObject}
  alias Plug.Conn

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  defp bypass_url(bypass), do: "http://127.0.0.1:#{bypass.port}"

  defp dummy_config(bypass),
    do: %Config{instance_url: bypass_url(bypass), access_token: "foo", api_version: "40.0"}

  test "versions", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/services/data", fn conn ->
      resp_body = """
      [
        {"label": "Winter '11", "url": "/services/data/v20.0", "version": "20.0"},
        {"label": "Spring '11", "url": "/services/data/v21.0", "version": "21.0"}
      ]
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, resp_body)
    end)

    {:ok, got} = ExForce.versions(bypass_url(bypass))

    assert got == [
             %{"label" => "Winter '11", "url" => "/services/data/v20.0", "version" => "20.0"},
             %{"label" => "Spring '11", "url" => "/services/data/v21.0", "version" => "21.0"}
           ]
  end

  test "resources", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/services/data/v38.0", fn conn ->
      resp_body = """
      {
        "tooling": "/services/data/v38.0/tooling",
        "eclair": "/services/data/v38.0/eclair"
      }
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, resp_body)
    end)

    {:ok, got} = ExForce.resources("38.0", dummy_config(bypass))

    assert got == %{
             "eclair" => "/services/data/v38.0/eclair",
             "tooling" => "/services/data/v38.0/tooling"
           }
  end

  test "resources with config as function", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/services/data/v38.0", fn conn ->
      resp_body = """
      {
        "tooling": "/services/data/v38.0/tooling",
        "eclair": "/services/data/v38.0/eclair"
      }
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, resp_body)
    end)

    f = fn -> dummy_config(bypass) end
    {:ok, got} = ExForce.resources("38.0", f)

    assert got == %{
             "eclair" => "/services/data/v38.0/eclair",
             "tooling" => "/services/data/v38.0/tooling"
           }
  end

  test "describe_sobject", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/services/data/v40.0/sobjects/Account/describe", fn conn ->
      resp_body = """
      {
        "actionOverrides": [],
        "activateable": false
      }
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, resp_body)
    end)

    {:ok, got} = ExForce.describe_sobject("Account", dummy_config(bypass))
    assert got == %{"actionOverrides" => [], "activateable" => false}
  end

  test "basic_info", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/services/data/v40.0/sobjects/Account", fn conn ->
      resp_body = """
      {
        "objectDescribe": {
          "label": "Account"
        },
        "recentItems": [
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v40.0/sobjects/Account/foo"
            },
            "Id": "foo",
            "Name": "name"
          }
        ]
      }
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, resp_body)
    end)

    {:ok, got} = ExForce.basic_info("Account", dummy_config(bypass))

    assert got == %{
             "objectDescribe" => %{"label" => "Account"},
             "recentItems" => [
               %SObject{id: "foo", type: "Account", data: %{"Id" => "foo", "Name" => "name"}}
             ]
           }
  end

  test "get_sobject", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/services/data/v40.0/sobjects/Account/foo", fn conn ->
      resp_body = """
      {
        "attributes": {
          "type": "Account",
          "url": "/services/data/v40.0/sobjects/Account/foo"
        },
        "Id": "foo",
        "Name": "name"
      }
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, resp_body)
    end)

    {:ok, got} = ExForce.get_sobject("foo", "Account", [], dummy_config(bypass))
    assert got == %SObject{id: "foo", type: "Account", data: %{"Id" => "foo", "Name" => "name"}}
  end

  test "get_sobject with fields", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/services/data/v40.0/sobjects/Account/foo", fn conn ->
      %{"fields" => "Name,Site"} = URI.decode_query(conn.query_string)

      resp_body = """
      {
        "attributes": {
          "type": "Account",
          "url": "/services/data/v40.0/sobjects/Account/foo"
        },
        "Id": "foo",
        "Name": "name",
        "Site": null
      }
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, resp_body)
    end)

    {:ok, got} = ExForce.get_sobject("foo", "Account", ["Name", "Site"], dummy_config(bypass))

    assert got == %SObject{
             id: "foo",
             type: "Account",
             data: %{"Id" => "foo", "Name" => "name", "Site" => nil}
           }
  end

  test "get_sobject_by_external_id", %{bypass: bypass} do
    Bypass.expect_once(
      bypass,
      "GET",
      "/services/data/v40.0/sobjects/Account/Foo__c/foo%20bar",
      fn conn ->
        resp_body = """
        {
          "attributes": {
            "type": "Account",
            "url": "/services/data/v40.0/sobjects/Account/foo"
          },
          "Id": "foo",
          "Name": "name"
        }
        """

        conn
        |> Conn.put_resp_content_type("application/json")
        |> Conn.resp(200, resp_body)
      end
    )

    {:ok, got} =
      ExForce.get_sobject_by_external_id("foo bar", "Foo__c", "Account", dummy_config(bypass))

    assert got == %SObject{id: "foo", type: "Account", data: %{"Id" => "foo", "Name" => "name"}}
  end

  test "get_sobject_by_relationship", %{bypass: bypass} do
    Bypass.expect_once(
      bypass,
      "GET",
      "/services/data/v40.0/sobjects/Account/foo/Owner",
      fn conn ->
        resp_body = """
        {
          "attributes": {
            "type": "User",
            "url": "/services/data/v40.0/sobjects/Owner/bar"
          },
          "Id": "bar",
          "Name": "name"
        }
        """

        conn
        |> Conn.put_resp_content_type("application/json")
        |> Conn.resp(200, resp_body)
      end
    )

    {:ok, got} =
      ExForce.get_sobject_by_relationship("foo", "Account", "Owner", [], dummy_config(bypass))

    assert got == %SObject{id: "bar", type: "User", data: %{"Id" => "bar", "Name" => "name"}}
  end

  test "get_sobject_by_relationship with fields", %{bypass: bypass} do
    Bypass.expect_once(
      bypass,
      "GET",
      "/services/data/v40.0/sobjects/Account/foo/Owner",
      fn conn ->
        %{"fields" => "FirstName,LastName"} = URI.decode_query(conn.query_string)

        resp_body = """
        {
          "attributes": {
            "type": "User",
            "url": "/services/data/v40.0/sobjects/Owner/bar"
          },
          "FirstName": "first_name",
          "LastName": "last_name"
        }
        """

        conn
        |> Conn.put_resp_content_type("application/json")
        |> Conn.resp(200, resp_body)
      end
    )

    {:ok, got} =
      ExForce.get_sobject_by_relationship(
        "foo",
        "Account",
        "Owner",
        ["FirstName", "LastName"],
        dummy_config(bypass)
      )

    assert got == %SObject{
             id: "bar",
             type: "User",
             data: %{"FirstName" => "first_name", "LastName" => "last_name"}
           }
  end

  test "update_sobject - success", %{bypass: bypass} do
    Bypass.expect_once(bypass, "PATCH", "/services/data/v40.0/sobjects/Account/foo", fn conn ->
      {:ok, raw, conn} = Conn.read_body(conn)
      expected_body = %{"FirstName" => "first_name"}
      ^expected_body = Poison.decode!(raw)
      Conn.resp(conn, 204, "")
    end)

    :ok =
      ExForce.update_sobject(
        "foo",
        "Account",
        %{"FirstName" => "first_name"},
        dummy_config(bypass)
      )
  end

  test "update_sobject - failure", %{bypass: bypass} do
    Bypass.expect_once(bypass, "PATCH", "/services/data/v40.0/sobjects/Account/foo", fn conn ->
      {:ok, raw, conn} = Conn.read_body(conn)
      expected_body = %{"x" => "foo"}
      ^expected_body = Poison.decode!(raw)

      resp_body = """
        [
          {
            "message": "No such column 'x' on sobject of type Account",
            "errorCode": "INVALID_FIELD"
          }
        ]
      """

      ^expected_body = Poison.decode!(raw)

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(400, resp_body)
    end)

    {:error, got} =
      ExForce.update_sobject("foo", "Account", %{"x" => "foo"}, dummy_config(bypass))

    assert got == [
             %{
               "errorCode" => "INVALID_FIELD",
               "message" => "No such column 'x' on sobject of type Account"
             }
           ]
  end

  test "delete_sobject - success", %{bypass: bypass} do
    Bypass.expect_once(bypass, "DELETE", "/services/data/v40.0/sobjects/Account/foo", fn conn ->
      Conn.resp(conn, 204, "")
    end)

    :ok = ExForce.delete_sobject("foo", "Account", dummy_config(bypass))
  end

  test "delete_sobject - failure", %{bypass: bypass} do
    Bypass.expect_once(bypass, "DELETE", "/services/data/v40.0/sobjects/Account/foo", fn conn ->
      resp_body = """
      [
        {
          "errorCode": "NOT_FOUND",
          "message": "Provided external ID field does not exist or is not accessible: foo"
        }
      ]
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(404, resp_body)
    end)

    {:error, got} = ExForce.delete_sobject("foo", "Account", dummy_config(bypass))

    assert got == [
             %{
               "errorCode" => "NOT_FOUND",
               "message" => "Provided external ID field does not exist or is not accessible: foo"
             }
           ]
  end

  test "query - sobjects", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/services/data/v40.0/query", fn conn ->
      %{"q" => "SELECT Name, Owner.Name FROM Account LIMIT 1"} =
        URI.decode_query(conn.query_string)

      resp_body = """
      {
        "totalSize": 1,
        "done": true,
        "records": [
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v40.0/sobjects/Account/foo"
            },
            "Name": "account name",
            "Owner": {
              "attributes": {
                "type": "User",
                "url": "/services/data/v40.0/sobjects/User/bar"
              },
              "Name": "user name"
            }
          }
        ]
      }
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, resp_body)
    end)

    {:ok, got} =
      ExForce.query("SELECT Name, Owner.Name FROM Account LIMIT 1", dummy_config(bypass))

    assert got == %QueryResult{
             done: true,
             next_records_url: nil,
             records: [
               %SObject{
                 id: "foo",
                 type: "Account",
                 data: %{
                   "Name" => "account name",
                   "Owner" => %SObject{
                     id: "bar",
                     type: "User",
                     data: %{"Name" => "user name"}
                   }
                 }
               }
             ],
             total_size: 1
           }
  end

  test "query - sobjects with next url", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/services/data/v40.0/query", fn conn ->
      %{"q" => "SELECT Name FROM Account"} = URI.decode_query(conn.query_string)

      resp_body = """
      {
        "totalSize": 500,
        "done": false,
        "nextRecordsUrl": "/services/data/v40.0/query/queryid-2000",
        "records": [
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v40.0/sobjects/Account/foo"
            },
            "Name": "account name"
          }
        ]
      }
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, resp_body)
    end)

    {:ok, got} = ExForce.query("SELECT Name FROM Account", dummy_config(bypass))

    assert got == %QueryResult{
             done: false,
             next_records_url: "/services/data/v40.0/query/queryid-2000",
             records: [
               %SObject{id: "foo", type: "Account", data: %{"Name" => "account name"}}
             ],
             total_size: 500
           }
  end

  test "query - aggregate", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/services/data/v40.0/query", fn conn ->
      %{"q" => "SELECT COUNT(Id) count_id FROM Account"} = URI.decode_query(conn.query_string)

      resp_body = """
      {
        "totalSize": 1,
        "done": true,
        "records": [
          {
            "attributes": {
              "type": "AggregateResult"
            },
            "count_id": 7
          }
        ]
      }
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, resp_body)
    end)

    {:ok, got} = ExForce.query("SELECT COUNT(Id) count_id FROM Account", dummy_config(bypass))

    assert got == %QueryResult{
             done: true,
             next_records_url: nil,
             records: [%SObject{data: %{"count_id" => 7}, type: "AggregateResult"}],
             total_size: 1
           }
  end

  test "query_stream", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/services/data/v40.0/query", fn conn ->
      %{"q" => "SELECT Name FROM Account"} = URI.decode_query(conn.query_string)

      resp_body = """
      {
        "totalSize": 4,
        "done": false,
        "nextRecordsUrl": "/services/data/v40.0/query/queryid-200",
        "records": [
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v40.0/sobjects/Account/account1"
            },
            "Name": "account1"
          },
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v40.0/sobjects/Account/account2"
            },
            "Name": "account2"
          }
        ]
      }
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, resp_body)
    end)

    Bypass.expect_once(bypass, "GET", "/services/data/v40.0/query/queryid-200", fn conn ->
      resp_body = """
      {
        "totalSize": 4,
        "done": true,
        "records": [
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v40.0/sobjects/Account/account3"
            }
          },
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v40.0/sobjects/Account/account4"
            }
          }
        ]
      }
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, resp_body)
    end)

    got =
      "SELECT Name FROM Account"
      |> ExForce.query_stream(dummy_config(bypass))
      |> Enum.map(fn %SObject{id: id} -> id end)
      |> Enum.to_list()

    assert got == ["account1", "account2", "account3", "account4"]
  end

  test "query_retrieve with query id", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/services/data/v40.0/query/queryid-200", fn conn ->
      resp_body = """
      {
        "totalSize": 500,
        "done": false,
        "nextRecordsUrl": "/services/data/v40.0/query/queryid-400",
        "records": [
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v40.0/sobjects/Account/foo"
            },
            "Name": "account name"
          }
        ]
      }
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, resp_body)
    end)

    {:ok, got} = ExForce.query_retrieve("queryid-200", dummy_config(bypass))

    assert got == %QueryResult{
             done: false,
             next_records_url: "/services/data/v40.0/query/queryid-400",
             records: [
               %SObject{id: "foo", type: "Account", data: %{"Name" => "account name"}}
             ],
             total_size: 500
           }
  end

  test "query_retrieve with next url", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/services/data/v40.0/query/queryid-200", fn conn ->
      resp_body = """
      {
        "totalSize": 500,
        "done": false,
        "nextRecordsUrl": "/services/data/v40.0/query/queryid-400",
        "records": [
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v40.0/sobjects/Account/foo"
            },
            "Name": "account name"
          }
        ]
      }
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, resp_body)
    end)

    {:ok, got} =
      ExForce.query_retrieve("/services/data/v40.0/query/queryid-200", dummy_config(bypass))

    assert got == %QueryResult{
             done: false,
             next_records_url: "/services/data/v40.0/query/queryid-400",
             records: [
               %SObject{id: "foo", type: "Account", data: %{"Name" => "account name"}}
             ],
             total_size: 500
           }
  end

  test "query_all - sobjects", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/services/data/v40.0/queryAll", fn conn ->
      %{"q" => "SELECT Name, Owner.Name FROM Account LIMIT 1"} =
        URI.decode_query(conn.query_string)

      resp_body = """
      {
        "totalSize": 1,
        "done": true,
        "records": [
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v40.0/sobjects/Account/foo"
            },
            "Name": "account name",
            "Owner": {
              "attributes": {
                "type": "User",
                "url": "/services/data/v40.0/sobjects/User/bar"
              },
              "Name": "user name"
            }
          }
        ]
      }
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, resp_body)
    end)

    {:ok, got} =
      ExForce.query_all("SELECT Name, Owner.Name FROM Account LIMIT 1", dummy_config(bypass))

    assert got == %QueryResult{
             done: true,
             next_records_url: nil,
             records: [
               %SObject{
                 id: "foo",
                 type: "Account",
                 data: %{
                   "Name" => "account name",
                   "Owner" => %SObject{
                     id: "bar",
                     type: "User",
                     data: %{"Name" => "user name"}
                   }
                 }
               }
             ],
             total_size: 1
           }
  end

  test "query_all_stream", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/services/data/v40.0/queryAll", fn conn ->
      %{"q" => "SELECT Name FROM Account"} = URI.decode_query(conn.query_string)

      resp_body = """
      {
        "totalSize": 4,
        "done": false,
        "nextRecordsUrl": "/services/data/v40.0/query/queryid-200",
        "records": [
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v40.0/sobjects/Account/account1"
            },
            "Name": "account1"
          },
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v40.0/sobjects/Account/account2"
            },
            "Name": "account2"
          }
        ]
      }
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, resp_body)
    end)

    Bypass.expect_once(bypass, "GET", "/services/data/v40.0/query/queryid-200", fn conn ->
      resp_body = """
      {
        "totalSize": 4,
        "done": true,
        "records": [
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v40.0/sobjects/Account/account3"
            }
          },
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v40.0/sobjects/Account/account4"
            }
          }
        ]
      }
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, resp_body)
    end)

    got =
      "SELECT Name FROM Account"
      |> ExForce.query_all_stream(dummy_config(bypass))
      |> Enum.map(fn %SObject{id: id} -> id end)
      |> Enum.to_list()

    assert got == ["account1", "account2", "account3", "account4"]
  end

  test "stream_query_result - zero result", %{bypass: bypass} do
    initial = %QueryResult{
      records: [],
      done: true
    }

    got =
      initial
      |> ExForce.stream_query_result(dummy_config(bypass))
      |> Enum.map(fn %SObject{id: id} -> id end)
      |> Enum.to_list()

    assert got == []
  end

  test "stream_query_result - zero page", %{bypass: bypass} do
    initial = %QueryResult{
      records: [
        %SObject{id: "account1"},
        %SObject{id: "account2"}
      ],
      done: true
    }

    got =
      initial
      |> ExForce.stream_query_result(dummy_config(bypass))
      |> Enum.map(fn %SObject{id: id} -> id end)
      |> Enum.to_list()

    assert got == ["account1", "account2"]
  end

  test "stream_query_result - two pages", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/services/data/v40.0/query/queryid-200", fn conn ->
      resp_body = """
      {
        "totalSize": 6,
        "done": false,
        "nextRecordsUrl": "/services/data/v40.0/query/queryid-400",
        "records": [
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v40.0/sobjects/Account/account3"
            }
          },
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v40.0/sobjects/Account/account4"
            }
          }
        ]
      }
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, resp_body)
    end)

    Bypass.expect_once(bypass, "GET", "/services/data/v40.0/query/queryid-400", fn conn ->
      resp_body = """
      {
        "totalSize": 6,
        "done": true,
        "records": [
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v40.0/sobjects/Account/account5"
            }
          },
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v40.0/sobjects/Account/account6"
            }
          }
        ]
      }
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, resp_body)
    end)

    initial = %QueryResult{
      records: [
        %SObject{id: "account1"},
        %SObject{id: "account2"}
      ],
      done: false,
      next_records_url: "/services/data/v40.0/query/queryid-200"
    }

    got =
      initial
      |> ExForce.stream_query_result(dummy_config(bypass))
      |> Enum.map(fn %SObject{id: id} -> id end)
      |> Enum.to_list()

    assert got == ["account1", "account2", "account3", "account4", "account5", "account6"]
  end
end
