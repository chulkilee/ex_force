defmodule ExForceTest do
  use ExUnit.Case, async: true
  doctest(ExForce)

  alias ExForce.{AuthRequest, Config}
  alias Plug.Conn

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  defp bypass_url(bypass), do: "http://127.0.0.1:#{bypass.port}"

  defp dummy_config(bypass),
    do: %Config{instance_url: bypass_url(bypass), access_token: "foo", api_version: "40.0"}

  test "authenticate - success", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/services/oauth2/token", fn conn ->
      ["application/x-www-form-urlencoded" <> _] = Conn.get_req_header(conn, "content-type")
      {:ok, raw, conn} = Conn.read_body(conn)

      expected_body = %{
        "client_id" => "client_id_foo",
        "client_secret" => "client_secret_bar",
        "grant_type" => "password",
        "password" => "password_barsecret_token_foo",
        "username" => "username_foo"
      }

      ^expected_body = URI.decode_query(raw)

      resp_body = """
      {
        "access_token": "access_token_foo",
        "instance_url": "https://example.com",
        "issued_at": "1505149885697"
      }
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, resp_body)
    end)

    ar = %AuthRequest{
      endpoint: bypass_url(bypass),
      client_id: "client_id_foo",
      client_secret: "client_secret_bar",
      username: "username_foo",
      password: "password_bar",
      security_token: "secret_token_foo",
      api_version: "40.0"
    }

    {:ok, expected_issued_at, 0} = DateTime.from_iso8601("2017-09-11T17:11:25.697Z")
    {:ok, got} = ExForce.authenticate(ar)

    assert got == %Config{
             access_token: "access_token_foo",
             api_version: "40.0",
             instance_url: "https://example.com",
             issued_at: expected_issued_at
           }
  end

  test "authenticate - failure", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/services/oauth2/token", fn conn ->
      resp_body = """
      {
        "error": "invalid_grant",
        "error_description": "authentication failure"
      }
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(400, resp_body)
    end)

    ar = %AuthRequest{
      endpoint: bypass_url(bypass),
      client_id: "client_id_foo",
      client_secret: "client_secret_bar",
      username: "username_foo",
      password: "password_bar",
      api_version: "40.0"
    }

    {:error, got} = ExForce.authenticate(ar)

    assert got == %{
             "error" => "invalid_grant",
             "error_description" => "authentication failure"
           }
  end

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
end
