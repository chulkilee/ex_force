defmodule ExForce.OAuthTest do
  use ExUnit.Case, async: true
  doctest(ExForce.OAuth)

  alias ExForce.{OAuth, OAuthResponse}
  alias Plug.Conn

  setup do
    with bypass <- Bypass.open(),
         client <- OAuth.build_client(bypass_url(bypass)) do
      {:ok, bypass: bypass, client: client}
    end
  end

  def bypass_url(bypass), do: "http://127.0.0.1:#{bypass.port}"

  test "authorize_url/2 returns URL for response_type=code" do
    assert OAuth.authorize_url(
             "https://login.salesforce.com",
             response_type: :code,
             client_id: "client_id_foo",
             redirect_uri: "http://127.0.0.1:8080/callback",
             scope: "api refresh_token"
           ) ==
             "https://login.salesforce.com/services/oauth2/authorize?response_type=code&client_id=client_id_foo&redirect_uri=http%3A%2F%2F127.0.0.1%3A8080%2Fcallback&scope=api+refresh_token"
  end

  test "authorize_url/2 returns URL for response_type=token" do
    assert OAuth.authorize_url(
             "https://login.salesforce.com",
             response_type: :token,
             client_id: "client_id_foo",
             redirect_uri: "http://127.0.0.1:8080/callback",
             scope: "api refresh_token"
           ) ==
             "https://login.salesforce.com/services/oauth2/authorize?response_type=token&client_id=client_id_foo&redirect_uri=http%3A%2F%2F127.0.0.1%3A8080%2Fcallback&scope=api+refresh_token"
  end

  test "get_token(:authorization_code) - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "POST", "/services/oauth2/token", fn conn ->
      ["application/x-www-form-urlencoded" <> _] = Conn.get_req_header(conn, "content-type")
      {:ok, raw, conn} = Conn.read_body(conn)

      expected_body = %{
        "grant_type" => "authorization_code",
        "client_id" => "client_id_foo",
        "client_secret" => "client_secret_bar",
        "code" => "code_foo",
        "redirect_uri" => "http://127.0.0.1:8080/callback"
      }

      ^expected_body = URI.decode_query(raw)

      resp_body = """
      {
        "access_token": "access_token_foo",
        "refresh_token": "refresh_token_foo",
        "signature": "RNy9G2E/bedQgdKoiqPGFgeIaxH0NR774kf1fwJvo8Y=",
        "scope": "refresh_token api",
        "instance_url": "https://example.com",
        "id": "https://example.com/id/fakeid",
        "token_type": "Bearer",
        "issued_at": "1505149885697"
      }
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, resp_body)
    end)

    {:ok, expected_issued_at, 0} = DateTime.from_iso8601("2017-09-11T17:11:25.697Z")

    {:ok, resp} =
      OAuth.get_token(
        client,
        grant_type: :authorization_code,
        client_id: "client_id_foo",
        client_secret: "client_secret_bar",
        code: "code_foo",
        redirect_uri: "http://127.0.0.1:8080/callback"
      )

    assert resp == %OAuthResponse{
             access_token: "access_token_foo",
             refresh_token: "refresh_token_foo",
             signature: "RNy9G2E/bedQgdKoiqPGFgeIaxH0NR774kf1fwJvo8Y=",
             scope: "refresh_token api",
             instance_url: "https://example.com",
             id: "https://example.com/id/fakeid",
             token_type: "Bearer",
             issued_at: expected_issued_at
           }
  end

  test "get_token(:authorization_code) - failure: invalid_grant", %{
    bypass: bypass,
    client: client
  } do
    Bypass.expect_once(bypass, "POST", "/services/oauth2/token", fn conn ->
      resp_body = """
      {
        "access_token": "access_token_foo",
        "refresh_token": "refresh_token_foo",
        "signature": "badsignature",
        "scope": "refresh_token api",
        "instance_url": "https://example.com",
        "id": "https://example.com/id/fakeid",
        "token_type": "Bearer",
        "issued_at": "1505149885697"
      }
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, resp_body)
    end)

    {:error, :invalid_signature} =
      OAuth.get_token(
        client,
        grant_type: :authorization_code,
        client_id: "client_id_foo",
        client_secret: "client_secret_bar",
        code: "code_foo",
        redirect_uri: "http://127.0.0.1:8080/callback"
      )
  end

  test "get_token(:authorization_code) - failure: :invalid_grant", %{
    bypass: bypass,
    client: client
  } do
    Bypass.expect_once(bypass, "POST", "/services/oauth2/token", fn conn ->
      resp_body = """
      {
        "error": "invalid_grant",
        "error_description": "expired authorization code"
      }
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(400, resp_body)
    end)

    {:error, resp} =
      OAuth.get_token(
        client,
        grant_type: :authorization_code,
        client_id: "client_id_foo",
        client_secret: "client_secret_bar",
        code: "code_foo",
        redirect_uri: "http://127.0.0.1:8080/callback"
      )

    assert resp == %{
             "error" => "invalid_grant",
             "error_description" => "expired authorization code"
           }
  end

  test "get_token(:refresh_token) - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "POST", "/services/oauth2/token", fn conn ->
      ["application/x-www-form-urlencoded" <> _] = Conn.get_req_header(conn, "content-type")
      {:ok, raw, conn} = Conn.read_body(conn)

      expected_body = %{
        "grant_type" => "refresh_token",
        "client_id" => "client_id_foo",
        "client_secret" => "client_secret_bar",
        "refresh_token" => "refresh_token_foo"
      }

      ^expected_body = URI.decode_query(raw)

      resp_body = """
      {
        "access_token": "access_token_foo",
        "signature": "RNy9G2E/bedQgdKoiqPGFgeIaxH0NR774kf1fwJvo8Y=",
        "scope": "refresh_token api",
        "instance_url": "https://example.com",
        "id": "https://example.com/id/fakeid",
        "token_type": "Bearer",
        "issued_at": "1505149885697"
      }
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, resp_body)
    end)

    {:ok, expected_issued_at, 0} = DateTime.from_iso8601("2017-09-11T17:11:25.697Z")

    {:ok, resp} =
      OAuth.get_token(
        client,
        grant_type: :refresh_token,
        client_id: "client_id_foo",
        client_secret: "client_secret_bar",
        refresh_token: "refresh_token_foo"
      )

    assert resp == %OAuthResponse{
             access_token: "access_token_foo",
             signature: "RNy9G2E/bedQgdKoiqPGFgeIaxH0NR774kf1fwJvo8Y=",
             scope: "refresh_token api",
             instance_url: "https://example.com",
             id: "https://example.com/id/fakeid",
             token_type: "Bearer",
             issued_at: expected_issued_at
           }
  end

  test "get_token(:refresh_token) - failure", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "POST", "/services/oauth2/token", fn conn ->
      resp_body = """
      {
        "error": "invalid_grant",
        "error_description": "expired access/refresh token"
      }
      """

      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(400, resp_body)
    end)

    {:error, resp} =
      OAuth.get_token(
        client,
        grant_type: :refresh_token,
        client_id: "client_id_foo",
        client_secret: "client_secret_bar",
        refresh_token: "refresh_token_foo"
      )

    assert resp == %{
             "error" => "invalid_grant",
             "error_description" => "expired access/refresh token"
           }
  end

  test "get_token(:password) - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "POST", "/services/oauth2/token", fn conn ->
      ["application/x-www-form-urlencoded" <> _] = Conn.get_req_header(conn, "content-type")
      {:ok, raw, conn} = Conn.read_body(conn)

      expected_body = %{
        "grant_type" => "password",
        "client_id" => "client_id_foo",
        "client_secret" => "client_secret_bar",
        "username" => "u@example.com",
        "password" => "a0!#$%-_=+<>"
      }

      ^expected_body = URI.decode_query(raw)

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

    {:ok, expected_issued_at, 0} = DateTime.from_iso8601("2017-09-11T17:11:25.697Z")

    {:ok, resp} =
      OAuth.get_token(
        client,
        grant_type: :password,
        client_id: "client_id_foo",
        client_secret: "client_secret_bar",
        username: "u@example.com",
        password: "a0!#$%-_=+<>"
      )

    assert resp == %OAuthResponse{
             access_token: "access_token_foo",
             instance_url: "https://example.com",
             id: "https://example.com/id/fakeid",
             token_type: "Bearer",
             issued_at: expected_issued_at,
             signature: "RNy9G2E/bedQgdKoiqPGFgeIaxH0NR774kf1fwJvo8Y="
           }
  end

  test "get_token - failure", %{bypass: bypass, client: client} do
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

    {:error, resp} =
      OAuth.get_token(
        client,
        grant_type: :password,
        client_id: "client_id_foo",
        client_secret: "client_secret_bar",
        username: "u@example.com",
        password: "a0!#$%-_=+<>"
      )

    assert resp == %{
             "error" => "invalid_grant",
             "error_description" => "authentication failure"
           }
  end
end
