defmodule ExForceTest do
  use ExUnit.Case, async: true
  doctest(ExForce)

  alias ExForce.{
    Client,
    QueryResult,
    Request,
    SObject
  }

  alias Plug.Conn

  @unreachable_url "http://257.0.0.0:0"

  setup do
    with bypass <- Bypass.open(),
         client <-
           ExForce.build_client(
             %{instance_url: bypass_url(bypass), access_token: "foo"},
             api_version: "53.0"
           ) do
      {:ok, bypass: bypass, client: client}
    end
  end

  defp bypass_url(bypass), do: "http://127.0.0.1:#{bypass.port}"

  defp client_with_econnrefused,
    do: ExForce.build_client(%{instance_url: @unreachable_url, access_token: "foo"})

  def assert_req_header(conn, key, expected) do
    assert expected == Conn.get_req_header(conn, key)
    conn
  end

  defp assert_json_body(conn, expected) do
    assert_req_header(conn, "content-type", ["application/json"])
    assert {:ok, raw, conn} = Conn.read_body(conn)
    assert Jason.decode!(raw) == expected
    conn
  end

  def assert_query_params(conn, expected) do
    assert URI.decode_query(conn.query_string) == expected
    conn
  end

  defp map_sobject_id(enum), do: Enum.map(enum, fn %SObject{id: id} -> id end)

  test "build_client/2 - map", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/", fn conn ->
      conn
      |> assert_req_header("authorization", ["Bearer foo"])
      |> assert_req_header("user-agent", ["ex_force"])
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, ~w({"hello": "world"}))
    end)

    client = ExForce.build_client(%{instance_url: bypass_url(bypass), access_token: "foo"})
    assert {:ok, %{status: 200, body: %{"hello" => "world"}}} = get(client, "/")
  end

  test "build_client/2 - string", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/", fn conn ->
      conn
      |> assert_req_header("authorization", [])
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, ~w({"hello": "world"}))
    end)

    client = ExForce.build_client(bypass_url(bypass))
    assert {:ok, %{status: 200, body: %{"hello" => "world"}}} = get(client, "/")
  end

  test "build_client/2 - headers", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/", fn conn ->
      conn
      |> assert_req_header("user-agent", [])
      |> assert_req_header("foo", ["bar"])
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, ~w({"hello": "world"}))
    end)

    client = ExForce.build_client(bypass_url(bypass), headers: [{"foo", "bar"}])
    assert {:ok, %{status: 200, body: %{"hello" => "world"}}} = get(client, "/")
  end

  test "build_client/2 - url - api_version - default v42.0", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/services/data/v42.0/foo", fn conn ->
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, ~w({"hello": "world"}))
    end)

    client = ExForce.build_client(bypass_url(bypass))
    assert {:ok, %{status: 200, body: %{"hello" => "world"}}} = get(client, "foo")
  end

  test "build_client/2 - url - api_version - opts", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/services/data/v12345.0/foo", fn conn ->
      conn
      |> assert_req_header("user-agent", ["ex_force"])
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, ~w({"hello": "world"}))
    end)

    client = ExForce.build_client(bypass_url(bypass), api_version: "12345.0")
    assert {:ok, %{status: 200, body: %{"hello" => "world"}}} = get(client, "foo")
  end

  test "build_client/2 - url - /foo", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/foo", fn conn ->
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, ~w({"hello": "world"}))
    end)

    client = ExForce.build_client(bypass_url(bypass), api_version: "12345.0")
    assert {:ok, %{status: 200, body: %{"hello" => "world"}}} = get(client, "/foo")
  end

  test "versions/1 - success", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/services/data", fn conn ->
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, """
      [
        {"label": "Winter '11", "url": "/services/data/v20.0", "version": "20.0"},
        {"label": "Spring '11", "url": "/services/data/v21.0", "version": "21.0"}
      ]
      """)
    end)

    assert ExForce.versions(bypass_url(bypass)) ==
             {:ok,
              [
                %{"label" => "Winter '11", "url" => "/services/data/v20.0", "version" => "20.0"},
                %{"label" => "Spring '11", "url" => "/services/data/v21.0", "version" => "21.0"}
              ]}
  end

  test "versions/1 - network error" do
    assert ExForce.versions(@unreachable_url) == {:error, :econnrefused}
  end

  test "resources/2 - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/services/data/v38.0", fn conn ->
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, """
      {
        "tooling": "/services/data/v38.0/tooling",
        "eclair": "/services/data/v38.0/eclair"
      }
      """)
    end)

    assert ExForce.resources(client, "38.0") ==
             {:ok,
              %{
                "eclair" => "/services/data/v38.0/eclair",
                "tooling" => "/services/data/v38.0/tooling"
              }}
  end

  test "resources/1 - network error" do
    assert ExForce.resources(client_with_econnrefused(), "38.0") == {:error, :econnrefused}
  end

  test "describe_global/1 - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/services/data/v53.0/sobjects", fn conn ->
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, """
      {
        "encoding": "UTF-8",
        "maxBatchSize": 200,
        "sobjects": [
          {
            "activateable": false,
            "name": "Account",
            "urls": {
              "sobject": "/services/data/v53.0/sobjects/Account"
            }
          }
        ]
      }
      """)
    end)

    assert ExForce.describe_global(client) ==
             {:ok,
              %{
                "encoding" => "UTF-8",
                "maxBatchSize" => 200,
                "sobjects" => [
                  %{
                    "activateable" => false,
                    "name" => "Account",
                    "urls" => %{"sobject" => "/services/data/v53.0/sobjects/Account"}
                  }
                ]
              }}
  end

  test "describe_global/1 - network error" do
    assert ExForce.describe_global(client_with_econnrefused()) == {:error, :econnrefused}
  end

  test "describe_sobject/2 - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/services/data/v53.0/sobjects/Account/describe", fn conn ->
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, """
      {
        "actionOverrides": [],
        "activateable": false
      }
      """)
    end)

    assert ExForce.describe_sobject(client, "Account") ==
             {:ok, %{"actionOverrides" => [], "activateable" => false}}
  end

  test "describe_sobject/2 - network error" do
    assert ExForce.describe_sobject(client_with_econnrefused(), "Account") ==
             {:error, :econnrefused}
  end

  test "basic_info/2 - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/services/data/v53.0/sobjects/Account", fn conn ->
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, """
      {
        "objectDescribe": {
          "label": "Account"
        },
        "recentItems": [
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v53.0/sobjects/Account/foo"
            },
            "Id": "foo",
            "Name": "name"
          }
        ]
      }
      """)
    end)

    assert ExForce.basic_info(client, "Account") ==
             {:ok,
              %{
                "objectDescribe" => %{"label" => "Account"},
                "recentItems" => [
                  %SObject{id: "foo", type: "Account", data: %{"Id" => "foo", "Name" => "name"}}
                ]
              }}
  end

  test "basic_info/2 - network error" do
    assert ExForce.basic_info(client_with_econnrefused(), "Account") == {:error, :econnrefused}
  end

  test "get_sobject/4 - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/services/data/v53.0/sobjects/Account/foo", fn conn ->
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, """
      {
        "attributes": {
          "type": "Account",
          "url": "/services/data/v53.0/sobjects/Account/foo"
        },
        "Id": "foo",
        "Name": "name"
      }
      """)
    end)

    assert ExForce.get_sobject(client, "foo", "Account", []) ==
             {:ok, %SObject{id: "foo", type: "Account", data: %{"Id" => "foo", "Name" => "name"}}}
  end

  test "get_sobject/4 - success with fields", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/services/data/v53.0/sobjects/Account/foo", fn conn ->
      conn
      |> assert_query_params(%{"fields" => "Name,Site"})
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, """
      {
        "attributes": {
          "type": "Account",
          "url": "/services/data/v53.0/sobjects/Account/foo"
        },
        "Id": "foo",
        "Name": "name",
        "Site": null
      }
      """)
    end)

    assert ExForce.get_sobject(client, "foo", "Account", ["Name", "Site"]) ==
             {:ok,
              %SObject{
                id: "foo",
                type: "Account",
                data: %{"Id" => "foo", "Name" => "name", "Site" => nil}
              }}
  end

  test "get_sobject/4 - network error" do
    assert ExForce.get_sobject(client_with_econnrefused(), "foo", "Account", []) ==
             {:error, :econnrefused}
  end

  test "get_sobject_by_external_id/4", %{bypass: bypass, client: client} do
    Bypass.expect_once(
      bypass,
      "GET",
      "/services/data/v53.0/sobjects/Account/Foo__c/foo%20bar",
      fn conn ->
        conn
        |> Conn.put_resp_content_type("application/json")
        |> Conn.resp(200, """
        {
          "attributes": {
            "type": "Account",
            "url": "/services/data/v53.0/sobjects/Account/foo"
          },
          "Id": "foo",
          "Name": "name"
        }
        """)
      end
    )

    assert ExForce.get_sobject_by_external_id(client, "foo bar", "Foo__c", "Account") ==
             {:ok, %SObject{id: "foo", type: "Account", data: %{"Id" => "foo", "Name" => "name"}}}
  end

  test "get_sobject_by_external_id/4 - network error" do
    assert ExForce.get_sobject_by_external_id(
             client_with_econnrefused(),
             "foo bar",
             "Foo__c",
             "Account"
           ) == {:error, :econnrefused}
  end

  test "get_sobject_by_relationship/5 - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(
      bypass,
      "GET",
      "/services/data/v53.0/sobjects/Account/foo/Owner",
      fn conn ->
        conn
        |> Conn.put_resp_content_type("application/json")
        |> Conn.resp(200, """
        {
          "attributes": {
            "type": "User",
            "url": "/services/data/v53.0/sobjects/Owner/bar"
          },
          "Id": "bar",
          "Name": "name"
        }
        """)
      end
    )

    assert ExForce.get_sobject_by_relationship(client, "foo", "Account", "Owner", []) ==
             {:ok, %SObject{id: "bar", type: "User", data: %{"Id" => "bar", "Name" => "name"}}}
  end

  test "get_sobject_by_relationship/5 - success with fields", %{bypass: bypass, client: client} do
    Bypass.expect_once(
      bypass,
      "GET",
      "/services/data/v53.0/sobjects/Account/foo/Owner",
      fn conn ->
        conn
        |> assert_query_params(%{"fields" => "FirstName,LastName"})
        |> Conn.put_resp_content_type("application/json")
        |> Conn.resp(200, """
        {
          "attributes": {
            "type": "User",
            "url": "/services/data/v53.0/sobjects/Owner/bar"
          },
          "FirstName": "first_name",
          "LastName": "last_name"
        }
        """)
      end
    )

    assert ExForce.get_sobject_by_relationship(client, "foo", "Account", "Owner", [
             "FirstName",
             "LastName"
           ]) ==
             {:ok,
              %SObject{
                id: "bar",
                type: "User",
                data: %{"FirstName" => "first_name", "LastName" => "last_name"}
              }}
  end

  test "get_sobject_by_relationship/5 - success with multiple results", %{
    bypass: bypass,
    client: client
  } do
    Bypass.expect_once(
      bypass,
      "GET",
      "/services/data/v53.0/sobjects/Account/foo/Owners",
      fn conn ->
        conn
        |> assert_query_params(%{"fields" => "FirstName,LastName"})
        |> Conn.put_resp_content_type("application/json")
        |> Conn.resp(200, """
        {
          "done": true,
          "records": [
            {
              "attributes": {
                "type": "User",
                "url": "/services/data/v53.0/sobjects/Owner/foo"
              },
              "FirstName": "first_first_name",
              "LastName": "first_last_name"
            },
            {
              "attributes": {
                "type": "User",
                "url": "/services/data/v53.0/sobjects/Owner/bar"
              },
              "FirstName": "second_first_name",
              "LastName": "second_last_name"
            }
          ],
          "totalSize": 2
        }
        """)
      end
    )

    assert ExForce.get_sobject_by_relationship(client, "foo", "Account", "Owners", [
             "FirstName",
             "LastName"
           ]) ==
             {:ok,
              %ExForce.QueryResult{
                done: true,
                next_records_url: nil,
                records: [
                  %ExForce.SObject{
                    id: "foo",
                    type: "User",
                    data: %{"FirstName" => "first_first_name", "LastName" => "first_last_name"}
                  },
                  %ExForce.SObject{
                    id: "bar",
                    type: "User",
                    data: %{"FirstName" => "second_first_name", "LastName" => "second_last_name"}
                  }
                ],
                total_size: 2
              }}
  end

  test "get_sobject_by_relationship/5 - network error" do
    assert ExForce.get_sobject_by_relationship(
             client_with_econnrefused(),
             "foo",
             "Account",
             "Owner",
             []
           ) == {:error, :econnrefused}
  end

  test "create_sobject/3 - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "POST", "/services/data/v53.0/sobjects/Account/", fn conn ->
      conn
      |> assert_json_body(%{"FirstName" => "first_name"})
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(201, """
      {
        "id": "001D000000IqhSLIAZ",
        "errors": [],
        "success": true,
        "warnings": []
      }
      """)
    end)

    assert ExForce.create_sobject(client, "Account", %{"FirstName" => "first_name"}) ==
             {:ok, "001D000000IqhSLIAZ"}
  end

  test "create_sobject/3 - failure", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "POST", "/services/data/v53.0/sobjects/Account/", fn conn ->
      conn
      |> assert_json_body(%{"FirstName" => "first_name"})
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(400, """
        [
          {
            "message": "No such column 'x' on sobject of type Account",
            "errorCode": "INVALID_FIELD"
          }
        ]
      """)
    end)

    assert ExForce.create_sobject(client, "Account", %{"FirstName" => "first_name"}) ==
             {:error,
              [
                %{
                  "errorCode" => "INVALID_FIELD",
                  "message" => "No such column 'x' on sobject of type Account"
                }
              ]}
  end

  test "create_sobject/3 - network error" do
    assert ExForce.create_sobject(client_with_econnrefused(), "Account", %{
             "FirstName" => "first_name"
           }) == {:error, :econnrefused}
  end

  test "update_sobject/4 - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "PATCH", "/services/data/v53.0/sobjects/Account/foo", fn conn ->
      conn
      |> assert_json_body(%{"FirstName" => "first_name"})
      |> Conn.resp(204, "")
    end)

    assert ExForce.update_sobject(client, "foo", "Account", %{"FirstName" => "first_name"}) == :ok
  end

  test "update_sobject/4 - failure", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "PATCH", "/services/data/v53.0/sobjects/Account/foo", fn conn ->
      conn
      |> assert_json_body(%{"x" => "foo"})
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(400, """
        [
          {
            "message": "No such column 'x' on sobject of type Account",
            "errorCode": "INVALID_FIELD"
          }
        ]
      """)
    end)

    assert ExForce.update_sobject(client, "foo", "Account", %{"x" => "foo"}) ==
             {:error,
              [
                %{
                  "errorCode" => "INVALID_FIELD",
                  "message" => "No such column 'x' on sobject of type Account"
                }
              ]}
  end

  test "update_sobject/4 - network error" do
    assert ExForce.update_sobject(client_with_econnrefused(), "foo", "Account", %{"x" => "foo"}) ==
             {:error, :econnrefused}
  end

  test "update_sobjects/3 - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "PATCH", "/services/data/v53.0/composite/sobjects", fn conn ->
      conn
      |> assert_json_body(%{
        "allOrNone" => false,
        "records" => [
          %{
            "attributes" => %{"type" => "Account"},
            "email" => "myemail@email.com",
            "id" => "001D000000IqhSLIAZ"
          }
        ]
      })
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, """
      [{
        "id": "001D000000IqhSLIAZ",
        "errors": [],
        "success": true,
        "warnings": []
      }]
      """)
    end)

    records = [
      %{id: "001D000000IqhSLIAZ", attributes: %{type: "Account"}, email: "myemail@email.com"}
    ]

    assert ExForce.update_sobjects(client, records) ==
             {:ok,
              [
                %{
                  "id" => "001D000000IqhSLIAZ",
                  "errors" => [],
                  "warnings" => [],
                  "success" => true
                }
              ]}
  end

  test "update_sobjects/3 - network error" do
    records = [
      %{id: "001D000000IqhSLIAZ", attributes: %{type: "Account"}, email: "myemail@email.com"}
    ]

    assert ExForce.update_sobjects(client_with_econnrefused(), records) ==
             {:error, :econnrefused}
  end

  test "delete_sobject/3 - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "DELETE", "/services/data/v53.0/sobjects/Account/foo", fn conn ->
      Conn.resp(conn, 204, "")
    end)

    assert ExForce.delete_sobject(client, "foo", "Account") == :ok
  end

  test "delete_sobject/3 - failure", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "DELETE", "/services/data/v53.0/sobjects/Account/foo", fn conn ->
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(404, """
      [
        {
          "errorCode": "NOT_FOUND",
          "message": "Provided external ID field does not exist or is not accessible: foo"
        }
      ]
      """)
    end)

    assert ExForce.delete_sobject(client, "foo", "Account") ==
             {:error,
              [
                %{
                  "errorCode" => "NOT_FOUND",
                  "message" =>
                    "Provided external ID field does not exist or is not accessible: foo"
                }
              ]}
  end

  test "delete_sobject/3 - network error" do
    assert ExForce.delete_sobject(client_with_econnrefused(), "foo", "Account") ==
             {:error, :econnrefused}
  end

  test "query/2 - success - sobjects", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/services/data/v53.0/query", fn conn ->
      conn
      |> assert_query_params(%{"q" => "SELECT Name, Owner.Name FROM Account LIMIT 1"})
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, """
      {
        "totalSize": 1,
        "done": true,
        "records": [
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v53.0/sobjects/Account/foo"
            },
            "Name": "account name",
            "Owner": {
              "attributes": {
                "type": "User",
                "url": "/services/data/v53.0/sobjects/User/bar"
              },
              "Name": "user name"
            }
          }
        ]
      }
      """)
    end)

    assert ExForce.query(client, "SELECT Name, Owner.Name FROM Account LIMIT 1") ==
             {:ok,
              %QueryResult{
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
              }}
  end

  test "query/2 - success - sobjects with next url", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/services/data/v53.0/query", fn conn ->
      conn
      |> assert_query_params(%{"q" => "SELECT Name FROM Account"})
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, """
      {
        "totalSize": 500,
        "done": false,
        "nextRecordsUrl": "/services/data/v53.0/query/queryid-2000",
        "records": [
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v53.0/sobjects/Account/foo"
            },
            "Name": "account name"
          }
        ]
      }
      """)
    end)

    assert ExForce.query(client, "SELECT Name FROM Account") ==
             {:ok,
              %QueryResult{
                done: false,
                next_records_url: "/services/data/v53.0/query/queryid-2000",
                records: [
                  %SObject{id: "foo", type: "Account", data: %{"Name" => "account name"}}
                ],
                total_size: 500
              }}
  end

  test "query/2 - success - aggregate", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/services/data/v53.0/query", fn conn ->
      conn
      |> assert_query_params(%{"q" => "SELECT COUNT(Id) count_id FROM Account"})
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, """
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
      """)
    end)

    assert ExForce.query(client, "SELECT COUNT(Id) count_id FROM Account") ==
             {:ok,
              %QueryResult{
                done: true,
                next_records_url: nil,
                records: [%SObject{data: %{"count_id" => 7}, type: "AggregateResult"}],
                total_size: 1
              }}
  end

  test "query/2 - network error" do
    assert ExForce.query(client_with_econnrefused(), "SELECT COUNT(Id) count_id FROM Account") ==
             {:error, :econnrefused}
  end

  test "query_stream/2 - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/services/data/v53.0/query", fn conn ->
      conn
      |> assert_query_params(%{"q" => "SELECT Name FROM Account"})
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, """
      {
        "totalSize": 4,
        "done": false,
        "nextRecordsUrl": "/services/data/v53.0/query/queryid-200",
        "records": [
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v53.0/sobjects/Account/account1"
            },
            "Name": "account1"
          },
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v53.0/sobjects/Account/account2"
            },
            "Name": "account2"
          }
        ]
      }
      """)
    end)

    Bypass.expect_once(bypass, "GET", "/services/data/v53.0/query/queryid-200", fn conn ->
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, """
      {
        "totalSize": 4,
        "done": true,
        "records": [
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v53.0/sobjects/Account/account3"
            }
          },
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v53.0/sobjects/Account/account4"
            }
          }
        ]
      }
      """)
    end)

    stream = ExForce.query_stream(client, "SELECT Name FROM Account")

    assert map_sobject_id(stream) == ["account1", "account2", "account3", "account4"]
  end

  test "query_stream/2 - failure at the beginning", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/services/data/v53.0/query", fn conn ->
      conn
      |> assert_query_params(%{"q" => "SELECT Name FROM Account"})
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(500, """
      {
        "foo": "bar"
      }
      """)
    end)

    stream = ExForce.query_stream(client, "SELECT Name FROM Account")

    assert Enum.to_list(stream) == [{:error, %{"foo" => "bar"}}]
  end

  test "query_stream/2 - failure in the middle", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/services/data/v53.0/query", fn conn ->
      conn
      |> assert_query_params(%{"q" => "SELECT Name FROM Account"})
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, """
      {
        "totalSize": 4,
        "done": false,
        "nextRecordsUrl": "/services/data/v53.0/query/queryid-200",
        "records": [
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v53.0/sobjects/Account/account1"
            },
            "Name": "account1"
          },
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v53.0/sobjects/Account/account2"
            },
            "Name": "account2"
          }
        ]
      }
      """)
    end)

    Bypass.expect_once(bypass, "GET", "/services/data/v53.0/query/queryid-200", fn conn ->
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(500, """
      {
        "foo": "bar"
      }
      """)
    end)

    stream = ExForce.query_stream(client, "SELECT Name FROM Account")

    assert Enum.to_list(stream) == [
             %ExForce.SObject{data: %{"Name" => "account1"}, id: "account1", type: "Account"},
             %ExForce.SObject{data: %{"Name" => "account2"}, id: "account2", type: "Account"},
             {:error, %{"foo" => "bar"}}
           ]
  end

  test "query_retrieve/2 - success with query id", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/services/data/v53.0/query/queryid-200", fn conn ->
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, """
      {
        "totalSize": 500,
        "done": false,
        "nextRecordsUrl": "/services/data/v53.0/query/queryid-400",
        "records": [
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v53.0/sobjects/Account/foo"
            },
            "Name": "account name"
          }
        ]
      }
      """)
    end)

    assert ExForce.query_retrieve(client, "queryid-200") ==
             {:ok,
              %QueryResult{
                done: false,
                next_records_url: "/services/data/v53.0/query/queryid-400",
                records: [
                  %SObject{id: "foo", type: "Account", data: %{"Name" => "account name"}}
                ],
                total_size: 500
              }}
  end

  test "query_retrieve/2 - success with next url", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/services/data/v53.0/query/queryid-200", fn conn ->
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, """
      {
        "totalSize": 500,
        "done": false,
        "nextRecordsUrl": "/services/data/v53.0/query/queryid-400",
        "records": [
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v53.0/sobjects/Account/foo"
            },
            "Name": "account name"
          }
        ]
      }
      """)
    end)

    assert ExForce.query_retrieve(client, "/services/data/v53.0/query/queryid-200") ==
             {:ok,
              %QueryResult{
                done: false,
                next_records_url: "/services/data/v53.0/query/queryid-400",
                records: [
                  %SObject{id: "foo", type: "Account", data: %{"Name" => "account name"}}
                ],
                total_size: 500
              }}
  end

  test "query_retrieve/2 - network error" do
    assert ExForce.query_retrieve(
             client_with_econnrefused(),
             "/services/data/v53.0/query/queryid-200"
           ) == {:error, :econnrefused}
  end

  test "query_all/2 - success - sobjects", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/services/data/v53.0/queryAll", fn conn ->
      conn
      |> assert_query_params(%{"q" => "SELECT Name, Owner.Name FROM Account LIMIT 1"})
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, """
      {
        "totalSize": 1,
        "done": true,
        "records": [
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v53.0/sobjects/Account/foo"
            },
            "Name": "account name",
            "Owner": {
              "attributes": {
                "type": "User",
                "url": "/services/data/v53.0/sobjects/User/bar"
              },
              "Name": "user name"
            }
          }
        ]
      }
      """)
    end)

    assert ExForce.query_all(client, "SELECT Name, Owner.Name FROM Account LIMIT 1") ==
             {:ok,
              %QueryResult{
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
              }}
  end

  test "query_all/2 - network error" do
    assert ExForce.query_all(
             client_with_econnrefused(),
             "SELECT Name, Owner.Name FROM Account LIMIT 1"
           ) == {:error, :econnrefused}
  end

  test "query_all_stream/2 - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/services/data/v53.0/queryAll", fn conn ->
      conn
      |> assert_query_params(%{"q" => "SELECT Name FROM Account"})
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, """
      {
        "totalSize": 4,
        "done": false,
        "nextRecordsUrl": "/services/data/v53.0/query/queryid-200",
        "records": [
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v53.0/sobjects/Account/account1"
            },
            "Name": "account1"
          },
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v53.0/sobjects/Account/account2"
            },
            "Name": "account2"
          }
        ]
      }
      """)
    end)

    Bypass.expect_once(bypass, "GET", "/services/data/v53.0/query/queryid-200", fn conn ->
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, """
      {
        "totalSize": 4,
        "done": true,
        "records": [
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v53.0/sobjects/Account/account3"
            }
          },
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v53.0/sobjects/Account/account4"
            }
          }
        ]
      }
      """)
    end)

    stream = ExForce.query_all_stream(client, "SELECT Name FROM Account")

    assert map_sobject_id(stream) == ["account1", "account2", "account3", "account4"]
  end

  test "stream_query_result/2 - zero result", %{client: client} do
    initial = %QueryResult{
      records: [],
      done: true
    }

    stream = ExForce.stream_query_result(client, initial)

    assert map_sobject_id(stream) == []
  end

  test "stream_query_result/2 - zero page", %{client: client} do
    initial = %QueryResult{
      records: [
        %SObject{id: "account1"},
        %SObject{id: "account2"}
      ],
      done: true
    }

    stream = ExForce.stream_query_result(client, initial)

    assert map_sobject_id(stream) == ["account1", "account2"]
  end

  test "stream_query_result/2 - two pages", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/services/data/v53.0/query/queryid-200", fn conn ->
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, """
      {
        "totalSize": 6,
        "done": false,
        "nextRecordsUrl": "/services/data/v53.0/query/queryid-400",
        "records": [
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v53.0/sobjects/Account/account3"
            }
          },
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v53.0/sobjects/Account/account4"
            }
          }
        ]
      }
      """)
    end)

    Bypass.expect_once(bypass, "GET", "/services/data/v53.0/query/queryid-400", fn conn ->
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, """
      {
        "totalSize": 6,
        "done": true,
        "records": [
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v53.0/sobjects/Account/account5"
            }
          },
          {
            "attributes": {
              "type": "Account",
              "url": "/services/data/v53.0/sobjects/Account/account6"
            }
          }
        ]
      }
      """)
    end)

    initial = %QueryResult{
      records: [
        %SObject{id: "account1"},
        %SObject{id: "account2"}
      ],
      done: false,
      next_records_url: "/services/data/v53.0/query/queryid-200"
    }

    stream = ExForce.stream_query_result(client, initial)

    assert map_sobject_id(stream) == [
             "account1",
             "account2",
             "account3",
             "account4",
             "account5",
             "account6"
           ]
  end

  test "get_recently_viewed_items/2", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "GET", "/services/data/v53.0/recent/", fn conn ->
      %{"limit" => "2"} = URI.decode_query(conn.query_string)

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, """
      [{
        "attributes" :
        {
            "type" : "Account",
            "url" : "/services/data/v53.0/sobjects/Account/a06U000000CelH0IAJ"
        },
        "Id" : "a06U000000CelH0IAJ",
        "Name" : "Acme"
      },
      {
          "attributes" :
          {
              "type" : "Opportunity",
              "url" : "/services/data/v53.0/sobjects/Opportunity/a06U000000CelGvIAJ"
          },
          "Id" : "a06U000000CelGvIAJ",
          "Name" : "Acme - 600 Widgets"
      }]
      """)
    end)

    assert ExForce.get_recently_viewed_items(client, 2) ==
             {:ok,
              [
                %SObject{
                  id: "a06U000000CelH0IAJ",
                  type: "Account",
                  data: %{
                    "Id" => "a06U000000CelH0IAJ",
                    "Name" => "Acme"
                  }
                },
                %SObject{
                  id: "a06U000000CelGvIAJ",
                  type: "Opportunity",
                  data: %{"Id" => "a06U000000CelGvIAJ", "Name" => "Acme - 600 Widgets"}
                }
              ]}
  end

  defp get(client, url), do: Client.request(client, %Request{url: url, method: :get})
end
