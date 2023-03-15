defmodule ExForce.ConfigTest do
  # Must be set to async: false since this is manipulating global application config
  use ExUnit.Case, async: false

  alias ExForce.{
    Client,
    Request
  }

  alias Plug.Conn

  test "build_client/2 - custom config" do
    bypass = Bypass.open()
    bypass_url = "http://127.0.0.1:#{bypass.port}"

    api_version = "456.0"

    custom_middleware = [
      Tesla.Middleware.Telemetry,
      {Tesla.Middleware.Timeout, timeout: :timer.seconds(1)}
    ]

    custom_middleware_representation = [
      {Tesla.Middleware.Telemetry, :call, [[]]},
      {Tesla.Middleware.Timeout, :call, [[timeout: 1000]]}
    ]

    Application.put_env(:ex_force, ExForce.Client.Tesla,
      api_version: api_version,
      append_middleware: custom_middleware
    )

    on_exit(fn -> Application.delete_env(:ex_force, ExForce.Client.Tesla) end)

    Bypass.expect_once(bypass, "GET", "/foo", fn conn ->
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, ~w({"hello": "world"}))
    end)

    client = ExForce.build_client(bypass_url)

    assert %Tesla.Client{
             adapter: nil,
             fun: nil,
             post: [],
             pre:
               [
                 {ExForce.Client.Tesla.Middleware, :call, [{^bypass_url, ^api_version}]},
                 {Tesla.Middleware.Compression, :call, [[format: "gzip"]]},
                 {Tesla.Middleware.JSON, :call, [[engine: Jason]]},
                 {Tesla.Middleware.Headers, :call, [[{"user-agent", "ex_force"}]]}
               ] ++ ^custom_middleware_representation
           } = client

    assert {:ok, %{status: 200, body: %{"hello" => "world"}}} =
             Client.request(client, %Request{url: "/foo", method: :get})
  end
end
