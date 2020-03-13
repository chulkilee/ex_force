defmodule ExForce.Client.Tesla.Middleware do
  @moduledoc false

  @behaviour Tesla.Middleware

  @impl Tesla.Middleware
  def call(env, next, opts) do
    env
    |> apply_url(opts)
    |> Tesla.run(next)
  end

  defp apply_url(%{url: "/" <> _ = path} = env, {base, _api_version}),
    do: %{env | url: base <> path}

  defp apply_url(%{url: path} = env, {base, api_version}),
    do: %{env | url: base <> "/services/data/v" <> api_version <> "/" <> path}
end
