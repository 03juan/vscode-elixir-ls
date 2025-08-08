defmodule LargePhoenixApp.Accounts.UserSupervisor do
  @moduledoc """
  Supervisor for user-related processes.
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # User-related workers would go here
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
