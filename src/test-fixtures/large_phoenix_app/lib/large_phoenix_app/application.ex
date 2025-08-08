defmodule LargePhoenixApp.Application do
  @moduledoc """
  The LargePhoenixApp Application.

  This simulates a large Phoenix application for testing the IDE Coordinator
  with realistic module counts and complex dependencies.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Core business logic supervisors
      LargePhoenixApp.Accounts.UserSupervisor,
      LargePhoenixApp.Orders.OrderSupervisor,
      LargePhoenixApp.Payments.PaymentSupervisor,
      LargePhoenixApp.Inventory.InventorySupervisor,
      LargePhoenixApp.Notifications.NotificationSupervisor
    ]

    opts = [strategy: :one_for_one, name: LargePhoenixApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
