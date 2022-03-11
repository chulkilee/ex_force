defmodule ExForce.OAuthTest do
  use ExUnit.Case, async: true
  doctest(ExForce.OAuth)

  alias ExForce.{OAuth, OAuthResponse}
  alias Plug.Conn

  @unreachable_url "http://257.0.0.0:0"

  setup do
    with bypass <- Bypass.open(),
         client <- OAuth.build_client(bypass_url(bypass)) do
      {:ok, bypass: bypass, client: client}
    end
  end

  def bypass_url(bypass), do: "http://127.0.0.1:#{bypass.port}"

  defp assert_form_body(conn, expected) do
    ["application/x-www-form-urlencoded" <> _] = Conn.get_req_header(conn, "content-type")
    {:ok, raw, conn} = Conn.read_body(conn)
    assert URI.decode_query(raw) == expected
    conn
  end

  defp assert_form_body_jwt(conn) do
    ["application/x-www-form-urlencoded" <> _] = Conn.get_req_header(conn, "content-type")
    {:ok, raw, conn} = Conn.read_body(conn)

    assert %{"assertion" => _, "grant_type" => "urn:ietf:params:oauth:grant-type:jwt-bearer"} =
             URI.decode_query(raw)

    conn
  end

  defp to_issued_at(string) do
    {:ok, issued_at, 0} = DateTime.from_iso8601(string)
    issued_at
  end

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

  test "get_token/2 - authorization_code - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "POST", "/services/oauth2/token", fn conn ->
      conn
      |> assert_form_body(%{
        "grant_type" => "authorization_code",
        "client_id" => "client_id_foo",
        "client_secret" => "client_secret_bar",
        "code" => "code_foo",
        "redirect_uri" => "http://127.0.0.1:8080/callback"
      })
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, """
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
      """)
    end)

    assert OAuth.get_token(
             client,
             grant_type: :authorization_code,
             client_id: "client_id_foo",
             client_secret: "client_secret_bar",
             code: "code_foo",
             redirect_uri: "http://127.0.0.1:8080/callback"
           ) ==
             {:ok,
              %OAuthResponse{
                access_token: "access_token_foo",
                refresh_token: "refresh_token_foo",
                signature: "RNy9G2E/bedQgdKoiqPGFgeIaxH0NR774kf1fwJvo8Y=",
                scope: "refresh_token api",
                instance_url: "https://example.com",
                id: "https://example.com/id/fakeid",
                token_type: "Bearer",
                issued_at: to_issued_at("2017-09-11T17:11:25.697Z")
              }}
  end

  test "get_token/2 - authorization_code - invalid_grant", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "POST", "/services/oauth2/token", fn conn ->
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, """
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
      """)
    end)

    assert OAuth.get_token(
             client,
             grant_type: :authorization_code,
             client_id: "client_id_foo",
             client_secret: "client_secret_bar",
             code: "code_foo",
             redirect_uri: "http://127.0.0.1:8080/callback"
           ) == {:error, :invalid_signature}
  end

  test "get_token/2 - authorization_code - expired", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "POST", "/services/oauth2/token", fn conn ->
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(400, """
      {
        "error": "invalid_grant",
        "error_description": "expired authorization code"
      }
      """)
    end)

    assert OAuth.get_token(
             client,
             grant_type: :authorization_code,
             client_id: "client_id_foo",
             client_secret: "client_secret_bar",
             code: "code_foo",
             redirect_uri: "http://127.0.0.1:8080/callback"
           ) ==
             {:error,
              %{
                "error" => "invalid_grant",
                "error_description" => "expired authorization code"
              }}
  end

  test "get_token/2 - refresh_token - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "POST", "/services/oauth2/token", fn conn ->
      conn
      |> assert_form_body(%{
        "grant_type" => "refresh_token",
        "client_id" => "client_id_foo",
        "client_secret" => "client_secret_bar",
        "refresh_token" => "refresh_token_foo"
      })
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, """
      {
        "access_token": "access_token_foo",
        "signature": "RNy9G2E/bedQgdKoiqPGFgeIaxH0NR774kf1fwJvo8Y=",
        "scope": "refresh_token api",
        "instance_url": "https://example.com",
        "id": "https://example.com/id/fakeid",
        "token_type": "Bearer",
        "issued_at": "1505149885697"
      }
      """)
    end)

    assert OAuth.get_token(
             client,
             grant_type: :refresh_token,
             client_id: "client_id_foo",
             client_secret: "client_secret_bar",
             refresh_token: "refresh_token_foo"
           ) ==
             {:ok,
              %OAuthResponse{
                access_token: "access_token_foo",
                signature: "RNy9G2E/bedQgdKoiqPGFgeIaxH0NR774kf1fwJvo8Y=",
                scope: "refresh_token api",
                instance_url: "https://example.com",
                id: "https://example.com/id/fakeid",
                token_type: "Bearer",
                issued_at: to_issued_at("2017-09-11T17:11:25.697Z")
              }}
  end

  test "get_token/2 - refresh_token - expired", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "POST", "/services/oauth2/token", fn conn ->
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(400, """
      {
        "error": "invalid_grant",
        "error_description": "expired access/refresh token"
      }
      """)
    end)

    assert OAuth.get_token(
             client,
             grant_type: :refresh_token,
             client_id: "client_id_foo",
             client_secret: "client_secret_bar",
             refresh_token: "refresh_token_foo"
           ) ==
             {:error,
              %{
                "error" => "invalid_grant",
                "error_description" => "expired access/refresh token"
              }}
  end

  test "get_token/2 - password - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "POST", "/services/oauth2/token", fn conn ->
      conn
      |> assert_form_body(%{
        "grant_type" => "password",
        "client_id" => "client_id_foo",
        "client_secret" => "client_secret_bar",
        "username" => "u@example.com",
        "password" => "a0!#$%-_=+<>"
      })
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, """
      {
        "access_token": "access_token_foo",
        "instance_url": "https://example.com",
        "id": "https://example.com/id/fakeid",
        "token_type": "Bearer",
        "issued_at": "1505149885697",
        "signature": "RNy9G2E/bedQgdKoiqPGFgeIaxH0NR774kf1fwJvo8Y="
      }
      """)
    end)

    assert OAuth.get_token(
             client,
             grant_type: :password,
             client_id: "client_id_foo",
             client_secret: "client_secret_bar",
             username: "u@example.com",
             password: "a0!#$%-_=+<>"
           ) ==
             {:ok,
              %OAuthResponse{
                access_token: "access_token_foo",
                instance_url: "https://example.com",
                id: "https://example.com/id/fakeid",
                token_type: "Bearer",
                issued_at: to_issued_at("2017-09-11T17:11:25.697Z"),
                signature: "RNy9G2E/bedQgdKoiqPGFgeIaxH0NR774kf1fwJvo8Y="
              }}
  end

  test "get_token/2 - password - failure", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "POST", "/services/oauth2/token", fn conn ->
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(400, """
      {
        "error": "invalid_grant",
        "error_description": "authentication failure"
      }
      """)
    end)

    assert OAuth.get_token(
             client,
             grant_type: :password,
             client_id: "client_id_foo",
             client_secret: "client_secret_bar",
             username: "u@example.com",
             password: "a0!#$%-_=+<>"
           ) ==
             {:error,
              %{
                "error" => "invalid_grant",
                "error_description" => "authentication failure"
              }}
  end

  test "get_token/2 - jwt - success", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "POST", "/services/oauth2/token", fn conn ->
      conn
      |> assert_form_body_jwt()
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, """
      {
        "access_token": "access_token_foo",
        "id": "https://example.com/id/fakeid",
        "instance_url": "https://example.com",
        "token_type": "Bearer",
        "scope":"full"
      }
      """)
    end)

    assert OAuth.get_token(
             client,
             url: "https://example.com/id/fakeid",
             grant_type: "jwt",
             client_id: "client_id_foo",
             username: "u@example.com",
             jwt_key: """
             -----BEGIN RSA PRIVATE KEY-----
             MIICWwIBAAKBgQCzr8JYWco0zKTH61qBu+5b9cRp2eBuDwLXYvvNqO6GoJUsNZpl
             9cp7NzNZafM2akyH+88ygr4GmSejzGuCatqMskJZXDYnT8WT47a8RpOXUR96xqQa
             Q37a22QVb+97sj8yLBgIkGn3I0bysVXjwlrENCosy2Y0Fck5sOIvxmnjKQIDAQAB
             AoGAOrvivNpsvCGAY1DM/scdPLXzA96R+6eweBME1862WQ84c4D5/QYAr5H1mO6G
             72yDo5dtvMb7slBxopr5MWIYGYUbrAMn7jEo3l1GUigpEnBecXkkSTMnk/DwnNW+
             3gal2rFFIo4CR2c2pCFhfJYfxKspyEdah7qChUSDdjZg9LkCQQDYEnbwuct1e3yk
             Dym38gWzGqxfQy5mIDrvYHY5Za1LYy+t6RUTccCLI66iI241mLAlIL4ugZ3miNhQ
             CjMC/9OLAkEA1OQIxUHhtRA7pcw+LpuDyRPFHIZMQ0XTnOV2RFUhxenthMIV8HKX
             eED1VI+4Tx0zvWkjErzHdI94Z/s1UHAqmwJAbH75Em945okXURn8DM2OZxzhqQQG
             7GkKruB0/OU9Wzl225DKcHUSBcvpCKlZ0bfV2w7R8HBNZVEZrTcx3jOveQJATtu5
             M/hXdw5wSdYCIpmQk2czWIGWtkSjQjbtPBqczAb+6HJMVijcWrsVJSGnkAatJ7hO
             OZ6b811BqKKw+P7TiQJASGctccNhTmtm9o81RJWPRayBZHKYEVjnOjYlJM63KWQf
             MO5oLcaGvZJrOcmOlsRVPby/liZgX+NJ8m5BFaNZgQ==
             -----END RSA PRIVATE KEY-----
             """
           ) ==
             {:ok,
              %OAuthResponse{
                access_token: "access_token_foo",
                id: "https://example.com/id/fakeid",
                instance_url: "https://example.com",
                issued_at: nil,
                refresh_token: nil,
                scope: "full",
                signature: nil,
                token_type: "Bearer"
              }}
  end

  test "get_token/2 - jwt - failure", %{bypass: bypass, client: client} do
    Bypass.expect_once(bypass, "POST", "/services/oauth2/token", fn conn ->
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(400, """
      {
        "error": "invalid_grant",
        "error_description": "incorrect assertion"
      }
      """)
    end)

    assert OAuth.get_token(
             client,
             url: "https://example.com/id/fakeid",
             grant_type: "jwt",
             client_id: "client_id_foo",
             username: "u@example.com",
             jwt_key: """
             -----BEGIN RSA PRIVATE KEY-----
             MIICWwIBAAKBgQCzr8JYWco0zKTH61qBu+5b9cRp2eBuDwLXYvvNqO6GoJUsNZpl
             9cp7NzNZafM2akyH+88ygr4GmSejzGuCatqMskJZXDYnT8WT47a8RpOXUR96xqQa
             Q37a22QVb+97sj8yLBgIkGn3I0bysVXjwlrENCosy2Y0Fck5sOIvxmnjKQIDAQAB
             AoGAOrvivNpsvCGAY1DM/scdPLXzA96R+6eweBME1862WQ84c4D5/QYAr5H1mO6G
             72yDo5dtvMb7slBxopr5MWIYGYUbrAMn7jEo3l1GUigpEnBecXkkSTMnk/DwnNW+
             3gal2rFFIo4CR2c2pCFhfJYfxKspyEdah7qChUSDdjZg9LkCQQDYEnbwuct1e3yk
             Dym38gWzGqxfQy5mIDrvYHY5Za1LYy+t6RUTccCLI66iI241mLAlIL4ugZ3miNhQ
             CjMC/9OLAkEA1OQIxUHhtRA7pcw+LpuDyRPFHIZMQ0XTnOV2RFUhxenthMIV8HKX
             eED1VI+4Tx0zvWkjErzHdI94Z/s1UHAqmwJAbH75Em945okXURn8DM2OZxzhqQQG
             7GkKruB0/OU9Wzl225DKcHUSBcvpCKlZ0bfV2w7R8HBNZVEZrTcx3jOveQJATtu5
             M/hXdw5wSdYCIpmQk2czWIGWtkSjQjbtPBqczAb+6HJMVijcWrsVJSGnkAatJ7hO
             OZ6b811BqKKw+P7TiQJASGctccNhTmtm9o81RJWPRayBZHKYEVjnOjYlJM63KWQf
             MO5oLcaGvZJrOcmOlsRVPby/liZgX+NJ8m5BFaNZgQ==
             -----END RSA PRIVATE KEY-----
             """
           ) ==
             {:error,
              %{
                "error" => "invalid_grant",
                "error_description" => "incorrect assertion"
              }}
  end

  test "get_token/2 with url", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/services/oauth2/token", fn conn ->
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(400, """
      {
        "error": "invalid_grant",
        "error_description": "authentication failure"
      }
      """)
    end)

    assert OAuth.get_token(
             bypass_url(bypass),
             grant_type: :password,
             client_id: "client_id_foo",
             client_secret: "client_secret_bar",
             username: "u@example.com",
             password: "a0!#$%-_=+<>"
           ) ==
             {:error,
              %{
                "error" => "invalid_grant",
                "error_description" => "authentication failure"
              }}
  end

  test "get_token/2 with bad url" do
    assert OAuth.get_token(
             @unreachable_url,
             grant_type: :password,
             client_id: "client_id_foo",
             client_secret: "client_secret_bar",
             username: "u@example.com",
             password: "a0!#$%-_=+<>"
           ) == {:error, :econnrefused}
  end

  test "build_client/2 works" do
    opts = [headers: [{"user-agent", "agent"}]]
    client = OAuth.build_client(@unreachable_url, opts)

    assert client === %Tesla.Client{
             adapter: nil,
             fun: nil,
             post: [],
             pre: [
               {Tesla.Middleware.BaseUrl, :call, ["http://257.0.0.0:0"]},
               {Tesla.Middleware.Compression, :call, [[format: "gzip"]]},
               {Tesla.Middleware.FormUrlencoded, :call, [[]]},
               {Tesla.Middleware.DecodeJson, :call, [[engine: Jason]]},
               {Tesla.Middleware.Headers, :call, [[{"user-agent", "agent"}]]}
             ]
           }
  end
end
