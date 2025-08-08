defmodule Jason do
  @moduledoc """
  Fake Jason JSON library for testing ElixirLS IDE Coordinator.
  """

  @doc """
  Encodes data to JSON string, raising on error.
  """
  def encode!(data) do
    # Simplified JSON encoding for testing
    inspect(data)
  end

  @doc """
  Decodes JSON string to data, raising on error.
  """
  def decode!(_json) do
    # Simplified JSON decoding for testing
    %{}
  end
end

defmodule Decimal do
  @moduledoc """
  Fake Decimal library for testing ElixirLS IDE Coordinator.
  """

  defstruct sign: 1, coef: 0, exp: 0

  @doc """
  Creates a new decimal.
  """
  def new(value) when is_integer(value) do
    %__MODULE__{sign: if(value < 0, do: -1, else: 1), coef: abs(value), exp: 0}
  end

  def new(value) when is_binary(value) do
    case Integer.parse(value) do
      {int_val, _} -> new(int_val)
      :error -> %__MODULE__{}
    end
  end

  @doc """
  Adds two decimals.
  """
  def add(a, b) do
    %__MODULE__{sign: 1, coef: a.coef + b.coef, exp: 0}
  end
end

defmodule Phoenix.PubSub do
  @moduledoc """
  Fake Phoenix.PubSub for testing ElixirLS IDE Coordinator.
  """

  @doc """
  Broadcasts a message to a topic.
  """
  def broadcast(_pubsub, _topic, _message) do
    :ok
  end

  @doc """
  Subscribes current process to a topic.
  """
  def subscribe(_pubsub, _topic) do
    :ok
  end
end
