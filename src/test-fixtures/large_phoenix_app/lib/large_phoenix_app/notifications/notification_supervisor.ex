defmodule LargePhoenixApp.Notifications.NotificationSupervisor do
  @moduledoc """
  Supervisor for notification-related processes.
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Notification workers would go here
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
