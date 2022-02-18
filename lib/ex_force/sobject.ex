defmodule ExForce.SObject do
  @moduledoc """
  Represents a SObject in API responses.
  """

  @type t :: %__MODULE__{id: String.t() | nil, type: String.t(), data: map}

  defstruct [:id, :type, :data]

  @doc """
  Transforms a `Map` into `ExForce.SObject` recursively.
  """
  @spec build(map) :: t
  def build(%{"attributes" => %{}} = raw), do: do_build(raw)

  def build([%{"attributes" => %{"url" => _, "type" => _}, "Id" => _, "Name" => _} | _] = raw) do
    Enum.map(raw, fn val ->
      do_build(val)
    end)
  end

  defp do_build(%{"attributes" => %{"type" => type, "url" => url}} = val) do
    id = url |> String.split("/") |> List.last()
    %__MODULE__{type: type, id: id, data: do_build_data(val)}
  end

  defp do_build(%{"attributes" => %{"type" => type}} = val) do
    %__MODULE__{type: type, data: do_build_data(val)}
  end

  defp do_build(val), do: val

  defp do_build_data(val) do
    val
    |> Map.delete("attributes")
    |> Enum.into(%{}, fn {k, v} -> {k, do_build(v)} end)
  end
end
