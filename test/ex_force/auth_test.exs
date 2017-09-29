defmodule ExForce.AuthTest do
  use ExUnit.Case, async: true
  doctest(ExForce.Auth)

  alias ExForce.{Auth, Config}
  alias ExForce.OAuth.Config, as: OAuthConfig
  alias Plug.Conn

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  defp bypass_url(bypass), do: "http://127.0.0.1:#{bypass.port}"

  test "get_config - success", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/services/oauth2/token", fn conn ->
      ["application/x-www-form-urlencoded" <> _] = Conn.get_req_header(conn, "content-type")

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

  test "get_config - failure", %{bypass: bypass} do
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
    oauth_config = %OAuthConfig{
      endpoint: bypass_url(bypass),
      client_id: "client_id_foo",
      client_secret: "client_secret_bar"
    }

    credentials = {"username_foo", "password_barsecret_token_foo"}
    api_version = "40.0"
    {oauth_config, credentials, api_version}
  end
end
