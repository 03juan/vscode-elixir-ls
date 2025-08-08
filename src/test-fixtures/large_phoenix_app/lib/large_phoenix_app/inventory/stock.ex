defmodule LargePhoenixApp.Inventory.Stock do
  @moduledoc """
  Stock management with complex inventory tracking.
  Dependencies: Product
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias LargePhoenixApp.Inventory.Product

  schema "stock" do
    field :quantity_available, :integer, default: 0
    field :quantity_reserved, :integer, default: 0
    field :quantity_on_order, :integer, default: 0
    field :reorder_point, :integer, default: 10
    field :max_stock_level, :integer, default: 100
    field :last_restocked_at, :naive_datetime

    belongs_to :product, Product

    timestamps()
  end

  def changeset(stock, attrs) do
    stock
    |> cast(attrs, [:quantity_available, :quantity_reserved, :quantity_on_order,
                    :reorder_point, :max_stock_level, :last_restocked_at])
    |> validate_number(:quantity_available, greater_than_or_equal_to: 0)
    |> validate_number(:quantity_reserved, greater_than_or_equal_to: 0)
    |> validate_number(:reorder_point, greater_than_or_equal_to: 0)
  end

  def get_available_quantity(product_id) do
    # Complex stock calculation with reservations
    case get_stock_record(product_id) do
      nil -> 0
      stock ->
        available = stock.quantity_available - stock.quantity_reserved
        max(available, 0)
    end
  end

  defp get_stock_record(product_id) do
    # Simulated stock lookup
    case product_id do
      100 -> %__MODULE__{
        product_id: 100,
        quantity_available: 50,
        quantity_reserved: 5,
        quantity_on_order: 20,
        reorder_point: 10
      }
      101 -> %__MODULE__{
        product_id: 101,
        quantity_available: 25,
        quantity_reserved: 2,
        quantity_on_order: 10,
        reorder_point: 5
      }
      _ -> nil
    end
  end

  def reserve_quantity(product_id, quantity) do
    # Complex reservation logic with validation
    with {:ok, stock} <- get_stock_for_update(product_id),
         {:ok, validated_stock} <- validate_reservation(stock, quantity),
         {:ok, updated_stock} <- update_reservations(validated_stock, quantity) do

      reservation_id = generate_reservation_id()
      store_reservation(reservation_id, product_id, quantity)

      {:ok, reservation_id}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_stock_for_update(product_id) do
    case get_stock_record(product_id) do
      nil -> {:error, "Product not found"}
      stock -> {:ok, stock}
    end
  end

  defp validate_reservation(stock, requested_quantity) do
    available = stock.quantity_available - stock.quantity_reserved

    if available >= requested_quantity do
      {:ok, stock}
    else
      {:error, "Insufficient stock for reservation"}
    end
  end

  defp update_reservations(stock, quantity) do
    updated_stock = %{stock | quantity_reserved: stock.quantity_reserved + quantity}
    {:ok, updated_stock}
  end

  defp generate_reservation_id() do
    :crypto.strong_rand_bytes(8) |> Base.encode64()
  end

  defp store_reservation(reservation_id, product_id, quantity) do
    # Store reservation record for tracking
    # In real app, this would be a database insert
    :ok
  end

  def cancel_reservation(reservation_id) do
    # Complex reservation cancellation
    with {:ok, reservation} <- get_reservation(reservation_id),
         {:ok, stock} <- get_stock_for_update(reservation.product_id),
         {:ok, _updated_stock} <- release_reserved_quantity(stock, reservation.quantity) do

      delete_reservation(reservation_id)
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_reservation(reservation_id) do
    # Simulated reservation lookup
    {:ok, %{id: reservation_id, product_id: 100, quantity: 2}}
  end

  defp release_reserved_quantity(stock, quantity) do
    updated_stock = %{stock | quantity_reserved: max(stock.quantity_reserved - quantity, 0)}
    {:ok, updated_stock}
  end

  defp delete_reservation(reservation_id) do
    # Delete reservation record
    :ok
  end

  def check_reorder_status(product_id) do
    # Complex reorder logic that coordinates with purchasing
    with {:ok, stock} <- get_stock_for_update(product_id),
         {:ok, product} <- Product.get_by_id(product_id) do

      available_stock = stock.quantity_available - stock.quantity_reserved
      total_incoming = stock.quantity_on_order

      analysis = %{
        current_available: available_stock,
        reserved: stock.quantity_reserved,
        on_order: total_incoming,
        reorder_point: stock.reorder_point,
        max_level: stock.max_stock_level,
        needs_reorder: available_stock <= stock.reorder_point,
        reorder_quantity: calculate_reorder_quantity(stock, available_stock)
      }

      {:ok, analysis}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp calculate_reorder_quantity(stock, available_stock) do
    if available_stock <= stock.reorder_point do
      # Calculate optimal reorder quantity
      target_stock = stock.max_stock_level
      current_total = available_stock + stock.quantity_on_order

      reorder_quantity = max(target_stock - current_total, 0)

      # Ensure minimum order quantity
      min_order = 10
      max(reorder_quantity, min_order)
    else
      0
    end
  end

  def update_stock_levels(product_id, changes) do
    # Complex stock update with validation and history tracking
    with {:ok, current_stock} <- get_stock_for_update(product_id),
         {:ok, validated_changes} <- validate_stock_changes(current_stock, changes),
         {:ok, updated_stock} <- apply_stock_changes(current_stock, validated_changes),
         {:ok, _} <- record_stock_movement(product_id, validated_changes) do

      {:ok, updated_stock}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_stock_changes(current_stock, changes) do
    # Validate that stock changes won't result in negative values
    new_available = current_stock.quantity_available + Map.get(changes, :quantity_change, 0)

    if new_available >= current_stock.quantity_reserved do
      {:ok, changes}
    else
      {:error, "Stock change would result in insufficient available quantity"}
    end
  end

  defp apply_stock_changes(stock, changes) do
    updated_stock = Enum.reduce(changes, stock, fn
      {:quantity_change, delta}, acc ->
        %{acc | quantity_available: acc.quantity_available + delta}
      {:reorder_point, new_point}, acc ->
        %{acc | reorder_point: new_point}
      {:max_stock_level, new_max}, acc ->
        %{acc | max_stock_level: new_max}
      {_key, _value}, acc ->
        acc
    end)

    {:ok, updated_stock}
  end

  defp record_stock_movement(product_id, changes) do
    # Record stock movement for audit trail
    movement = %{
      product_id: product_id,
      changes: changes,
      timestamp: NaiveDateTime.utc_now(),
      reason: Map.get(changes, :reason, "manual_adjustment")
    }

    # In real app, this would be stored in stock_movements table
    {:ok, movement}
  end
end
