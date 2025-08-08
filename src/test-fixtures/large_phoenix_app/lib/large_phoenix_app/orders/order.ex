defmodule LargePhoenixApp.Orders.Order do
  @moduledoc """
  Order management with complex state transitions.

  This module demonstrates complex business logic with multiple dependencies
  that benefit from coordinated debugging.

  Dependencies: User, OrderItem, Payment, Inventory modules
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias LargePhoenixApp.Accounts.User
  alias LargePhoenixApp.Orders.OrderItem
  alias LargePhoenixApp.Payments.Payment
  alias LargePhoenixApp.Inventory.{Product, Stock}
  alias LargePhoenixApp.Notifications.EmailService

  @statuses ["pending", "confirmed", "processing", "shipped", "delivered", "cancelled", "refunded"]

  schema "orders" do
    field :order_number, :string
    field :status, :string, default: "pending"
    field :subtotal, :decimal
    field :tax_amount, :decimal
    field :shipping_amount, :decimal
    field :total_amount, :decimal
    field :notes, :string
    field :shipped_at, :naive_datetime
    field :delivered_at, :naive_datetime

    belongs_to :user, User
    has_many :order_items, OrderItem
    has_many :payments, Payment

    timestamps()
  end

  def changeset(order, attrs) do
    order
    |> cast(attrs, [:status, :notes, :shipped_at, :delivered_at])
    |> validate_inclusion(:status, @statuses)
    |> validate_status_transition()
  end

  def get_recent_for_user(user_id) do
    # Simulated recent orders lookup
    # This would be called from User module, creating cross-module dependency
    recent_cutoff = NaiveDateTime.utc_now() |> NaiveDateTime.add(-30, :day)

    [
      %__MODULE__{id: 1, user_id: user_id, status: "delivered", inserted_at: recent_cutoff},
      %__MODULE__{id: 2, user_id: user_id, status: "shipped", inserted_at: NaiveDateTime.utc_now()}
    ]
  end

  def process_order(order) do
    # Complex order processing pipeline that coordinates multiple modules
    # Perfect scenario for IDE Coordinator to manage interpretation
    with {:ok, validated_order} <- validate_order_items(order),
         {:ok, _reserved_inventory} <- reserve_inventory(validated_order),
         {:ok, _processed_payment} <- process_payment(validated_order),
         {:ok, updated_order} <- update_order_status(validated_order, "confirmed") do

      # Send confirmation notification
      EmailService.send_order_confirmation(updated_order)
      {:ok, updated_order}
    else
      {:error, reason} ->
        rollback_order_processing(order)
        {:error, reason}
    end
  end

  defp validate_order_items(order) do
    # Validate each item - coordinates with Inventory modules
    order_items = get_order_items(order.id)

    Enum.reduce_while(order_items, {:ok, order}, fn item, {:ok, acc_order} ->
      case validate_single_item(item) do
        {:ok, _validated_item} -> {:cont, {:ok, acc_order}}
        {:error, error_reason} -> {:halt, {:error, "Item validation failed: #{error_reason}"}}
      end
    end)
  end

  defp get_order_items(order_id) do
    # Simulated order items lookup
    [
      %OrderItem{id: 1, order_id: order_id, product_id: 100, quantity: 2, unit_price: Decimal.new("29.99")},
      %OrderItem{id: 2, order_id: order_id, product_id: 101, quantity: 1, unit_price: Decimal.new("49.99")}
    ]
  end

  defp validate_single_item(order_item) do
    # Complex item validation - depends on Product and Stock modules
    with {:ok, product} <- get_product(order_item.product_id),
         {:ok, _stock} <- check_stock_availability(product, order_item.quantity),
         {:ok, _pricing} <- validate_pricing(order_item, product) do
      {:ok, order_item}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_product(product_id) do
    # This creates dependency on Inventory.Product module
    Product.get_by_id(product_id)
  end

  defp check_stock_availability(product, requested_quantity) do
    # This creates dependency on Inventory.Stock module
    case Stock.get_available_quantity(product.id) do
      stock_available when stock_available >= requested_quantity ->
        {:ok, stock_available}
      stock_available ->
        {:error, "Insufficient stock. Available: #{stock_available}, Requested: #{requested_quantity}"}
    end
  end

  defp validate_pricing(order_item, product) do
    product_current_price = Product.get_current_price(product)

    if Decimal.equal?(order_item.unit_price, product_current_price) do
      {:ok, order_item}
    else
      {:error, "Price mismatch. Current: #{product_current_price}, Order: #{order_item.unit_price}"}
    end
  end

  defp reserve_inventory(order) do
    # Reserve inventory for all items - coordinates with Stock module
    order_items = get_order_items(order.id)

    reservations = Enum.map(order_items, fn item ->
      Stock.reserve_quantity(item.product_id, item.quantity)
    end)

    if Enum.all?(reservations, &match?({:ok, _}, &1)) do
      {:ok, order}
    else
      # Rollback any successful reservations
      rollback_reservations(reservations)
      {:error, "Failed to reserve inventory"}
    end
  end

  defp rollback_reservations(reservations) do
    Enum.each(reservations, fn
      {:ok, reservation_id} -> Stock.cancel_reservation(reservation_id)
      {:error, _} -> :ok
    end)
  end

  defp process_payment(order) do
    # Process payment - coordinates with Payment module
    case Payment.process_order_payment(order) do
      {:ok, _payment} -> {:ok, order}
      {:error, payment_reason} -> {:error, "Payment failed: #{payment_reason}"}
    end
  end

  defp update_order_status(order, new_status) do
    # Simulated status update
    updated_order = %{order | status: new_status}
    {:ok, updated_order}
  end

  defp rollback_order_processing(target_order) do
    # Complex rollback logic coordinating multiple modules
    with {:ok, _} <- cancel_inventory_reservations(target_order),
         {:ok, _} <- refund_payments(target_order),
         {:ok, _} <- update_order_status(target_order, "cancelled") do
      :ok
    else
      {:error, rollback_reason} ->
        require Logger
        Logger.error("Failed to rollback order #{target_order.id}: #{rollback_reason}")
        :error
    end
  end

  defp cancel_inventory_reservations(order) do
    # Cancel any inventory reservations
    {:ok, order}
  end

  defp refund_payments(order) do
    # Refund any processed payments
    {:ok, order}
  end

  defp validate_status_transition(changeset) do
    # Complex status transition validation
    changeset
  end

  def calculate_order_totals(order) do
    # Complex calculation that coordinates with multiple modules
    order_items = get_order_items(order.id)

    with {:ok, subtotal} <- calculate_subtotal(order_items),
         {:ok, tax_amount} <- calculate_tax(subtotal, order),
         {:ok, shipping_amount} <- calculate_shipping(order_items, order) do

      total_amount = Decimal.add(subtotal, Decimal.add(tax_amount, shipping_amount))

      {:ok, %{
        subtotal: subtotal,
        tax_amount: tax_amount,
        shipping_amount: shipping_amount,
        total_amount: total_amount
      }}
    else
      {:error, reason} -> {:error, "Failed to calculate totals: #{reason}"}
    end
  end

  defp calculate_subtotal(order_items) do
    subtotal = Enum.reduce(order_items, Decimal.new("0"), fn item, acc ->
      item_total = Decimal.mult(item.unit_price, item.quantity)
      Decimal.add(acc, item_total)
    end)

    {:ok, subtotal}
  end

  defp calculate_tax(subtotal, order) do
    # Tax calculation that might depend on user location
    user = get_user(order.user_id)
    tax_rate = get_tax_rate_for_user(user)
    tax_amount = Decimal.mult(subtotal, tax_rate)

    {:ok, tax_amount}
  end

  defp calculate_shipping(order_items, order) do
    # Shipping calculation based on items and user location
    total_weight = calculate_total_weight(order_items)
    user = get_user(order.user_id)
    shipping_zone = determine_shipping_zone(user)

    shipping_amount = calculate_shipping_cost(total_weight, shipping_zone)
    {:ok, shipping_amount}
  end

  defp get_user(user_id) do
    # This creates dependency back to User module
    %User{id: user_id, email: "test@example.com"}
  end

  defp get_tax_rate_for_user(_user) do
    Decimal.new("0.08")  # 8% tax rate
  end

  defp calculate_total_weight(order_items) do
    # Would coordinate with Product module to get weights
    Enum.reduce(order_items, 0, fn item, acc ->
      product_weight = Product.get_weight(item.product_id)
      acc + (product_weight * item.quantity)
    end)
  end

  defp determine_shipping_zone(_user) do
    # Complex zone determination logic
    :domestic
  end

  defp calculate_shipping_cost(total_weight, shipping_zone) do
    base_cost = case shipping_zone do
      :domestic -> Decimal.new("5.99")
      :international -> Decimal.new("15.99")
    end

    weight_cost = Decimal.mult(Decimal.new("0.50"), total_weight)
    Decimal.add(base_cost, weight_cost)
  end
end
