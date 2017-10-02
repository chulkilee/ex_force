defmodule ExForce.OAuthTest do
  use ExUnit.Case, async: true
  doctest(ExForce.OAuth)

  alias ExForce.OAuth
  alias ExForce.OAuth.{Config, Response}
  alias Plug.Conn

  @redirect_uri "http://127.0.0.1:80/foo"
  @code "code_foo"
  @refresh_token "refresh_token_foo"
  @username "username_foo"
  @password "password_bar"

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  test "authorize_url(:authorization_code)", %{bypass: bypass} do
    config = get_config(bypass)

    assert OAuth.authorize_url(
             :authorization_code,
             [redirect_uri: "http://127.0.0.1:80/foo", scope: "api refresh_token"],
             config
           ) ==
             "http://127.0.0.1:#{bypass.port}/services/oauth2/authorize?response_type=code&client_id=client_id_foo&redirect_uri=http%3A%2F%2F127.0.0.1%3A80%2Ffoo&scope=api+refresh_token"
  end

  test "authorize_url(:token)", %{bypass: bypass} do
    config = get_config(bypass)

    assert OAuth.authorize_url(
             :token,
             [redirect_uri: "http://127.0.0.1:80/foo", scope: "api refresh_token"],
             config
           ) ==
             "http://127.0.0.1:#{bypass.port}/services/oauth2/authorize?response_type=token&client_id=client_id_foo&redirect_uri=http%3A%2F%2F127.0.0.1%3A80%2Ffoo&scope=api+refresh_token"
  end

  test "get_token(:authorization_code) - success", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/services/oauth2/token", fn conn ->
      ["application/x-www-form-urlencoded" <> _] = Conn.get_req_header(conn, "content-type")
      {:ok, raw, conn} = Conn.read_body(conn)

      expected_body = %{
        "client_id" => "client_id_foo",
        "client_secret" => "client_secret_bar",
        "grant_type" => "authorization_code",
        "code" => @code,
        "redirect_uri" => @redirect_uri
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

    config = get_config(bypass)

    {:ok, expected_issued_at, 0} = DateTime.from_iso8601("2017-09-11T17:11:25.697Z")

    {:ok, resp} =
      OAuth.get_token(:authorization_code, {@code, [redirect_uri: @redirect_uri]}, config)

    assert resp == %Response{
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

  test "get_token(:authorization_code) - failure: invalid_grant", %{bypass: bypass} do
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

    config = get_config(bypass)

    {:error, :invalid_signature} = OAuth.get_token(:authorization_code, @code, config)
  end

  test "get_token(:authorization_code) - failure: :invalid_grant", %{bypass: bypass} do
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

    config = get_config(bypass)

    {:error, resp} = OAuth.get_token(:authorization_code, @code, config)

    assert resp == %{
             "error" => "invalid_grant",
             "error_description" => "expired authorization code"
           }
  end

  test "get_token(:refresh_token) - success", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/services/oauth2/token", fn conn ->
      ["application/x-www-form-urlencoded" <> _] = Conn.get_req_header(conn, "content-type")
      {:ok, raw, conn} = Conn.read_body(conn)

      expected_body = %{
        "client_id" => "client_id_foo",
        "client_secret" => "client_secret_bar",
        "grant_type" => "refresh_token",
        "refresh_token" => @refresh_token
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

    config = get_config(bypass)

    {:ok, expected_issued_at, 0} = DateTime.from_iso8601("2017-09-11T17:11:25.697Z")
    {:ok, resp} = OAuth.get_token(:refresh_token, @refresh_token, config)

    assert resp == %Response{
             access_token: "access_token_foo",
             signature: "RNy9G2E/bedQgdKoiqPGFgeIaxH0NR774kf1fwJvo8Y=",
             scope: "refresh_token api",
             instance_url: "https://example.com",
             id: "https://example.com/id/fakeid",
             token_type: "Bearer",
             issued_at: expected_issued_at
           }
  end

  test "get_token(:refresh_token) - failure", %{bypass: bypass} do
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

    config = get_config(bypass)

    {:error, resp} = OAuth.get_token(:refresh_token, @refresh_token, config)

    assert resp == %{
             "error" => "invalid_grant",
             "error_description" => "expired access/refresh token"
           }
  end

  test "get_token(:password) - success", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/services/oauth2/token", fn conn ->
      ["application/x-www-form-urlencoded" <> _] = Conn.get_req_header(conn, "content-type")
      {:ok, raw, conn} = Conn.read_body(conn)

      expected_body = %{
        "client_id" => "client_id_foo",
        "client_secret" => "client_secret_bar",
        "grant_type" => "password",
        "password" => @password,
        "username" => @username
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

    config = get_config(bypass)

    {:ok, expected_issued_at, 0} = DateTime.from_iso8601("2017-09-11T17:11:25.697Z")
    {:ok, resp} = OAuth.get_token(:password, {@username, @password}, config)

    assert resp == %Response{
             access_token: "access_token_foo",
             instance_url: "https://example.com",
             id: "https://example.com/id/fakeid",
             token_type: "Bearer",
             issued_at: expected_issued_at,
             signature: "RNy9G2E/bedQgdKoiqPGFgeIaxH0NR774kf1fwJvo8Y="
           }
  end

  test "get_token - failure", %{bypass: bypass} do
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

    config = get_config(bypass)

    {:error, resp} = OAuth.get_token(:password, {@username, @password}, config)

    assert resp == %{
             "error" => "invalid_grant",
             "error_description" => "authentication failure"
           }
  end

  defp get_config(bypass) do
    %Config{
      endpoint: "http://127.0.0.1:#{bypass.port}",
      client_id: "client_id_foo",
      client_secret: "client_secret_bar"
    }
  end
end
