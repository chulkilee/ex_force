defmodule ExForce.ClientTest do
  use ExUnit.Case, async: true
  doctest(ExForce.Client)

  alias ExForce.{Client, Response}
  alias Plug.Conn

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  defp bypass_url(bypass), do: "http://127.0.0.1:#{bypass.port}"

  test "decode reponse body if content type is specified", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/", fn conn ->
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.resp(200, ~s({"foo": "bar"}))
    end)

    %Response{status_code: 200, body: got} = Client.request!(:get, bypass_url(bypass))
    assert %{"foo" => "bar"} == got
  end

  test "do not decode reponse body if content type is missing", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/", fn conn -> Conn.resp(conn, 200, "foo") end)
    %Response{status_code: 200, body: got} = Client.request!(:get, bypass_url(bypass))
    assert "foo" == got
  end

  test "handle gzip response", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/", fn conn ->
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.put_resp_header("content-encoding", "gzip")
      |> Conn.resp(200, :zlib.gzip(~s({"foo": "bar"})))
    end)

    %Response{status_code: 200, body: got, headers: headers} =
      Client.request!(:get, bypass_url(bypass))

    assert %{"foo" => "bar"} == got
    assert ["gzip"] == Map.get(headers, "content-encoding")
  end

  test "do not encode request body if string is given", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/", fn conn ->
      ["application/json"] = Conn.get_req_header(conn, "content-type")
      {:ok, raw, conn} = Conn.read_body(conn)
      %{"foo" => "bar"} = Poison.decode!(raw)
      Conn.resp(conn, 200, "")
    end)

    %Response{status_code: 200} = Client.request!(:post, bypass_url(bypass), ~s({"foo":"bar"}))
  end

  test "encode request body if map is given", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/", fn conn ->
      ["application/json"] = Conn.get_req_header(conn, "content-type")
      {:ok, raw, conn} = Conn.read_body(conn)
      %{"foo" => "bar"} = Poison.decode!(raw)
      Conn.resp(conn, 200, "")
    end)

    %Response{status_code: 200, body: ""} =
      Client.request!(:post, bypass_url(bypass), %{"foo" => "bar"})
  end

  test "encode request body if list is given", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/", fn conn ->
      ["application/json"] = Conn.get_req_header(conn, "content-type")
      {:ok, raw, conn} = Conn.read_body(conn)
      [1, 2] = Poison.decode!(raw)
      Conn.resp(conn, 200, "")
    end)

    %Response{status_code: 200, body: ""} = Client.request!(:post, bypass_url(bypass), [1, 2])
  end
end
