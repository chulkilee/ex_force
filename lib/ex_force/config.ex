defmodule ExForce.Config do
  @moduledoc """
  Holds authentication and endpoint information.
  """

  alias ExForce.OAuth.Response

  @type t :: %__MODULE__{
          access_token: String.t(),
          api_version: String.t(),
          instance_url: String.t()
        }

  defstruct [:access_token, :api_version, :instance_url]

  def from({:ok, %Response{access_token: access_token, instance_url: instance_url}}, api_version),
    do:
      {
        :ok,
        %__MODULE__{
          access_token: access_token,
          instance_url: instance_url,
          api_version: api_version
        }
      }

  def from({:error, error}, _api_version), do: {:error, error}
end
