defmodule ExForceTest do
  use ExUnit.Case, async: true
  doctest(ExForce)

  alias ExForce.{QueryResult, SObject}
  alias Plug.Conn

  setup do
    with bypass <- Bypass.open(),
         client <-
           ExForce.build_client(
             bypass_url(bypass),
             access_token: "foo",
             api_version: "40.0"
           ) do
      {:ok, bypass: bypass, client: client}
    end
  end

  def bypass_url(bypass), do: "http://127.0.0.1:#{bypass.port}"

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

  test "resources", %{bypass: bypass, client: client} do
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

    {:ok, got} = ExForce.resources(client, "38.0")

    assert got == %{
             "eclair" => "/services/data/v38.0/eclair",
             "tooling" => "/services/data/v38.0/tooling"
           }
  end

  test "describe_sobject", %{bypass: bypass, client: client} do
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

    {:ok, got} = ExForce.describe_sobject(client, "Account")
    assert got == %{"actionOverrides" => [], "activateable" => false}
  end

  test "basic_info", %{bypass: bypass, client: client} do
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

    {:ok, got} = ExForce.basic_info(client, "Account")

    assert got == %{
             "objectDescribe" => %{"label" => "Account"},
             "recentItems" => [
               %SObject{id: "foo", type: "Account", data: %{"Id" => "foo", "Name" => "name"}}
             ]
           }
  end

  test "get_sobject", %{bypass: bypass, client: client} do
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

    {:ok, got} = ExForce.get_sobject(client, "foo", "Account", [])
    assert got == %SObject{id: "foo", type: "Account", data: %{"Id" => "foo", "Name" => "name"}}
  end

  test "get_sobject with fields", %{bypass: bypass, client: client} do
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

    {:ok, got} = ExForce.get_sobject(client, "foo", "Account", ["Name", "Site"])

    assert got == %SObject{
             id: "foo",
             type: "Account",
             data: %{"Id" => "foo", "Name" => "name", "Site" => nil}
           }
  end

  test "get_sobject_by_external_id", %{bypass: bypass, client: client} do
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

    {:ok, got} = ExForce.get_sobject_by_external_id(client, "foo bar", "Foo__c", "Account")

    assert got == %SObject{id: "foo", type: "Account", data: %{"Id" => "foo", "Name" => "name"}}
  end

  test "get_sobject_by_relationship", %{bypass: bypass, client: client} do
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

    {:ok, got} = ExForce.get_sobject_by_relationship(client, "foo", "Account", "Owner", [])

    assert got == %SObject{id: "bar", type: "User", data: %{"Id" => "bar", "Name" => "name"}}
  end

  test "get_sobject_by_relationship with fields", %{bypass: bypass, client: client} do
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
      ExForce.get_sobject_by_relationship(client, "foo", "Account", "Owner", [
        "FirstName",
        "LastName"
      ])

    assert got == %SObject{
             id: "bar",
             type: "User",
             data: %{"FirstName" => "first_name", "LastName" => "last_name"}
           }
  end

  test "create_sobject - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "POST", "/services/data/v40.0/sobjects/Account/", fn conn ->
      {:ok, raw, conn} = Conn.read_body(conn)
      expected_body = %{"FirstName" => "first_name"}
      ^expected_body = Jason.decode!(raw)

      resp_body = """
      {
        "id": "001D000000IqhSLIAZ",
        "errors": [],
        "success": true,
        "warnings": []
      }
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(201, resp_body)
    end)

    {:ok, "001D000000IqhSLIAZ"} =
      ExForce.create_sobject(client, "Account", %{"FirstName" => "first_name"})
  end

  test "create_sobject - failure", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "POST", "/services/data/v40.0/sobjects/Account/", fn conn ->
      {:ok, raw, conn} = Conn.read_body(conn)
      expected_body = %{"FirstName" => "first_name"}
      ^expected_body = Jason.decode!(raw)

      resp_body = """
        [
          {
            "message": "No such column 'x' on sobject of type Account",
            "errorCode": "INVALID_FIELD"
          }
        ]
      """

      ^expected_body = Jason.decode!(raw)

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(400, resp_body)
    end)

    {:error, got} = ExForce.create_sobject(client, "Account", %{"FirstName" => "first_name"})

    assert got == [
             %{
               "errorCode" => "INVALID_FIELD",
               "message" => "No such column 'x' on sobject of type Account"
             }
           ]
  end

  test "update_sobject - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "PATCH", "/services/data/v40.0/sobjects/Account/foo", fn conn ->
      {:ok, raw, conn} = Conn.read_body(conn)
      expected_body = %{"FirstName" => "first_name"}
      ^expected_body = Jason.decode!(raw)
      Conn.resp(conn, 204, "")
    end)

    :ok = ExForce.update_sobject(client, "foo", "Account", %{"FirstName" => "first_name"})
  end

  test "update_sobject - failure", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "PATCH", "/services/data/v40.0/sobjects/Account/foo", fn conn ->
      {:ok, raw, conn} = Conn.read_body(conn)
      expected_body = %{"x" => "foo"}
      ^expected_body = Jason.decode!(raw)

      resp_body = """
        [
          {
            "message": "No such column 'x' on sobject of type Account",
            "errorCode": "INVALID_FIELD"
          }
        ]
      """

      ^expected_body = Jason.decode!(raw)

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(400, resp_body)
    end)

    {:error, got} = ExForce.update_sobject(client, "foo", "Account", %{"x" => "foo"})

    assert got == [
             %{
               "errorCode" => "INVALID_FIELD",
               "message" => "No such column 'x' on sobject of type Account"
             }
           ]
  end

  test "delete_sobject - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "DELETE", "/services/data/v40.0/sobjects/Account/foo", fn conn ->
      Conn.resp(conn, 204, "")
    end)

    :ok = ExForce.delete_sobject(client, "foo", "Account")
  end

  test "delete_sobject - failure", %{bypass: bypass, client: client} do
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

    {:error, got} = ExForce.delete_sobject(client, "foo", "Account")

    assert got == [
             %{
               "errorCode" => "NOT_FOUND",
               "message" => "Provided external ID field does not exist or is not accessible: foo"
             }
           ]
  end

  test "query - sobjects", %{bypass: bypass, client: client} do
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

    {:ok, got} = ExForce.query(client, "SELECT Name, Owner.Name FROM Account LIMIT 1")

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

  test "query - sobjects with next url", %{bypass: bypass, client: client} do
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

    {:ok, got} = ExForce.query(client, "SELECT Name FROM Account")

    assert got == %QueryResult{
             done: false,
             next_records_url: "/services/data/v40.0/query/queryid-2000",
             records: [
               %SObject{id: "foo", type: "Account", data: %{"Name" => "account name"}}
             ],
             total_size: 500
           }
  end

  test "query - aggregate", %{bypass: bypass, client: client} do
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

    {:ok, got} = ExForce.query(client, "SELECT COUNT(Id) count_id FROM Account")

    assert got == %QueryResult{
             done: true,
             next_records_url: nil,
             records: [%SObject{data: %{"count_id" => 7}, type: "AggregateResult"}],
             total_size: 1
           }
  end

  test "query_stream", %{bypass: bypass, client: client} do
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
      ExForce.query_stream(client, "SELECT Name FROM Account")
      |> Enum.map(fn %SObject{id: id} -> id end)
      |> Enum.to_list()

    assert got == ["account1", "account2", "account3", "account4"]
  end

  test "query_retrieve with query id", %{bypass: bypass, client: client} do
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

    {:ok, got} = ExForce.query_retrieve(client, "queryid-200")

    assert got == %QueryResult{
             done: false,
             next_records_url: "/services/data/v40.0/query/queryid-400",
             records: [
               %SObject{id: "foo", type: "Account", data: %{"Name" => "account name"}}
             ],
             total_size: 500
           }
  end

  test "query_retrieve with next url", %{bypass: bypass, client: client} do
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

    {:ok, got} = ExForce.query_retrieve(client, "/services/data/v40.0/query/queryid-200")

    assert got == %QueryResult{
             done: false,
             next_records_url: "/services/data/v40.0/query/queryid-400",
             records: [
               %SObject{id: "foo", type: "Account", data: %{"Name" => "account name"}}
             ],
             total_size: 500
           }
  end

  test "query_all - sobjects", %{bypass: bypass, client: client} do
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

    {:ok, got} = ExForce.query_all(client, "SELECT Name, Owner.Name FROM Account LIMIT 1")

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

  test "query_all_stream", %{bypass: bypass, client: client} do
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
      ExForce.query_all_stream(client, "SELECT Name FROM Account")
      |> Enum.map(fn %SObject{id: id} -> id end)
      |> Enum.to_list()

    assert got == ["account1", "account2", "account3", "account4"]
  end

  test "stream_query_result - zero result", %{client: client} do
    initial = %QueryResult{
      records: [],
      done: true
    }

    got =
      ExForce.stream_query_result(client, initial)
      |> Enum.map(fn %SObject{id: id} -> id end)
      |> Enum.to_list()

    assert got == []
  end

  test "stream_query_result - zero page", %{client: client} do
    initial = %QueryResult{
      records: [
        %SObject{id: "account1"},
        %SObject{id: "account2"}
      ],
      done: true
    }

    got =
      ExForce.stream_query_result(client, initial)
      |> Enum.map(fn %SObject{id: id} -> id end)
      |> Enum.to_list()

    assert got == ["account1", "account2"]
  end

  test "stream_query_result - two pages", %{bypass: bypass, client: client} do
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
      ExForce.stream_query_result(client, initial)
      |> Enum.map(fn %SObject{id: id} -> id end)
      |> Enum.to_list()

    assert got == ["account1", "account2", "account3", "account4", "account5", "account6"]
  end
end
