defmodule ExForce.QueryResult do
  @moduledoc """
  Represents the result of a query.
  """

  @type t :: %__MODULE__{done: boolean, next_records_url: String.t() | nil, records: list}

  defstruct [:done, :next_records_url, :records, :total_size]
end
