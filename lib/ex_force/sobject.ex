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
  def build(raw = %{"attributes" => %{}}), do: do_build(raw)

  defp do_build(val = %{"attributes" => %{"type" => type, "url" => url}}) do
    id = url |> String.split("/") |> List.last()
    %__MODULE__{type: type, id: id, data: do_build_data(val)}
  end

  defp do_build(val = %{"attributes" => %{"type" => type}}) do
    %__MODULE__{type: type, data: do_build_data(val)}
  end

  defp do_build(val), do: val

  defp do_build_data(val) do
    val
    |> Map.delete("attributes")
    |> Enum.map(fn {k, v} -> {k, do_build(v)} end)
    |> Enum.into(%{})
  end
end
