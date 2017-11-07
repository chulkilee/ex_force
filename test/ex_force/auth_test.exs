defmodule ExForce.AuthTest do
  use ExUnit.Case, async: true
  doctest(ExForce.Auth)

  alias ExForce.{Auth, Config}
  alias Plug.Conn

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  defp bypass_url(bypass), do: "http://127.0.0.1:#{bypass.port}"

  test "get - success", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/services/oauth2/token", fn conn ->
      ["application/x-www-form-urlencoded" <> _] = Conn.get_req_header(conn, "content-type")

      {:ok, raw, conn} = Conn.read_body(conn)

      assert URI.decode_query(raw) == %{
               "client_id" => "client_id_foo",
               "client_secret" => "client_secret_bar",
               "grant_type" => "password",
               "password" => "password_bar",
               "username" => "username_foo"
             }

      resp_body = """
      {
        "access_token": "access_token_foo",
        "instance_url": "https://example.com",
        "id": "https://example.com/id/fakeid",
        "token_type": "Bearer",
        "issued_at": "1505149885697",
        "signature": "RNy9G2E/bedQgdKoiqPGFgeIaxH0NR774kf1fwJvo8Y="
      }
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, resp_body)
    end)

    {:ok, pid} = Auth.start_link(args(bypass), name: DummyAuth)

    {:ok, got} = Auth.get(DummyAuth)

    assert got == %Config{
             access_token: "access_token_foo",
             api_version: "40.0",
             instance_url: "https://example.com"
           }

    ^got = Auth.get!(DummyAuth)

    GenServer.stop(pid)
  end

  test "get with load_from_system_env: success" do
    bypass = Bypass.open(port: 1234)

    Bypass.expect_once(bypass, "POST", "/services/oauth2/token", fn conn ->
      ["application/x-www-form-urlencoded" <> _] = Conn.get_req_header(conn, "content-type")
      {:ok, raw, conn} = Conn.read_body(conn)

      assert URI.decode_query(raw) == %{
               "client_id" => "client_id_env",
               "client_secret" => "client_secret_env",
               "grant_type" => "password",
               "password" => "password_envsecurity_token_env",
               "username" => "username_env"
             }

      resp_body = """
      {
        "access_token": "access_token_foo",
        "instance_url": "https://example.com",
        "id": "https://example.com/id/fakeid",
        "token_type": "Bearer",
        "issued_at": "1505149885697",
        "signature": "7wSn/rMpE/yycne6yRQnudaxddTC5hXrslU0R1bQb8M="
      }
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, resp_body)
    end)

    test_env = %{
      "SALESFORCE_ENDPOINT" => "http://127.0.0.1:1234",
      "SALESFORCE_CLIENT_ID" => "client_id_env",
      "SALESFORCE_CLIENT_SECRET" => "client_secret_env",
      "SALESFORCE_USERNAME" => "username_env",
      "SALESFORCE_PASSWORD" => "password_env",
      "SALESFORCE_SECURITY_TOKEN" => "security_token_env",
      "SALESFORCE_API_VERSION" => "api_version_env"
    }

    System.put_env(test_env)

    {:ok, pid} = Auth.start_link([load_from_system_env: true], name: DummyAuth)

    try do
      {:ok, got} = Auth.get(DummyAuth)

      assert got == %Config{
               access_token: "access_token_foo",
               api_version: "api_version_env",
               instance_url: "https://example.com"
             }

      ^got = Auth.get!(DummyAuth)
    after
      test_env |> Map.keys() |> Enum.map(&System.delete_env/1)
      GenServer.stop(pid)
    end
  end

  test "get - failure", %{bypass: bypass} do
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

    {:ok, pid} = Auth.start_link(args(bypass), name: DummyAuth)

    {:error, got} = Auth.get(DummyAuth)

    assert got == %{
             "error" => "invalid_grant",
             "error_description" => "authentication failure"
           }

    GenServer.stop(pid)
  end

  defp args(bypass) do
    [
      endpoint: bypass_url(bypass),
      client_id: "client_id_foo",
      client_secret: "client_secret_bar",
      username: "username_foo",
      password: "password_bar",
      secret_token: "secret_token_foo",
      api_version: "40.0"
    ]
  end
end
