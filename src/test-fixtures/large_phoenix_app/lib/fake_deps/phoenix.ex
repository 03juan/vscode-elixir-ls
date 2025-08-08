defmodule Phoenix.Controller do
  @moduledoc """
  Fake Phoenix.Controller for testing ElixirLS IDE Coordinator.
  """

  @doc """
  Renders a view.
  """
  def render(conn, template, assigns \\ %{}) do
    %{conn | resp_body: "Rendered #{template} with #{inspect(assigns)}"}
  end

  @doc """
  Redirects to a path.
  """
  def redirect(conn, opts) do
    %{conn | status: 302, resp_headers: [{"location", opts[:to]}]}
  end

  @doc """
  Sends JSON response.
  """
  def json(conn, data) do
    %{conn | resp_body: Jason.encode!(data), resp_headers: [{"content-type", "application/json"}]}
  end

  defmacro __using__(_opts) do
    quote do
      import Phoenix.Controller
    end
  end
end

defmodule Phoenix.Router do
  @moduledoc """
  Fake Phoenix.Router for testing ElixirLS IDE Coordinator.
  """

  @doc """
  Defines a GET route.
  """
  defmacro get(path, plug, plug_opts, opts \\ []) do
    quote do
      @routes {unquote(path), :get, unquote(plug), unquote(plug_opts), unquote(opts)}
    end
  end

  @doc """
  Defines a POST route.
  """
  defmacro post(path, plug, plug_opts, opts \\ []) do
    quote do
      @routes {unquote(path), :post, unquote(plug), unquote(plug_opts), unquote(opts)}
    end
  end

  @doc """
  Defines resources.
  """
  defmacro resources(path, controller, opts \\ []) do
    quote do
      @resources {unquote(path), unquote(controller), unquote(opts)}
    end
  end

  defmacro __using__(_opts) do
    quote do
      import Phoenix.Router
      Module.register_attribute(__MODULE__, :routes, accumulate: true)
      Module.register_attribute(__MODULE__, :resources, accumulate: true)
    end
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
