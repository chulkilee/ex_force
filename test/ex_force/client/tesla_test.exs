defmodule ExForce.Client.TeslaTest do
  use ExUnit.Case, async: false
  alias ExForce.{Client, Request}
  alias Plug.Conn

  defmodule TestMiddleware do
    @behaviour Tesla.Middleware

    @impl Tesla.Middleware
    def call(env, next, test_pid: test_pid, id: id) when is_pid(test_pid) do
      send(test_pid, {:before, id})
      result = Tesla.run(env, next)
      send(test_pid, {:after, id})

      result
    end
  end

  setup do
    %{bypass: Bypass.open()}
  end

  test "it will use the custom middleware provided to it", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/foo", fn conn ->
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, ~w({"hello": "world"}))
    end)

    client =
      ExForce.Client.Tesla.build_client(%{instance_url: bypass_url(bypass), access_token: "foo"},
        middleware: [
          {TestMiddleware, test_pid: self(), id: 1},
          {TestMiddleware, test_pid: self(), id: 2},
          {TestMiddleware, test_pid: self(), id: 3}
        ]
      )

    {:ok, _response} = Client.request(client, %Request{url: "/foo", method: :get})

    assert {:messages,
            [
              before: 1,
              before: 2,
              before: 3,
              after: 3,
              after: 2,
              after: 1
            ]} = Process.info(self(), :messages)
  end

  defp bypass_url(bypass), do: "http://127.0.0.1:#{bypass.port}"
end
