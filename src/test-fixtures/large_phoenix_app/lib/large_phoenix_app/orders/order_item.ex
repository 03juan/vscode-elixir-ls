defmodule LargePhoenixApp.Orders.OrderItem do
  @moduledoc """
  Individual items within an order.
  Dependencies: Order, Product
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias LargePhoenixApp.Orders.Order
  alias LargePhoenixApp.Inventory.Product

  schema "order_items" do
    field :quantity, :integer
    field :unit_price, :decimal
    field :total_price, :decimal

    belongs_to :order, Order
    belongs_to :product, Product

    timestamps()
  end

  def changeset(order_item, attrs) do
    order_item
    |> cast(attrs, [:quantity, :unit_price, :product_id])
    |> validate_required([:quantity, :unit_price, :product_id])
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:unit_price, greater_than: 0)
    |> calculate_total_price()
  end

  defp calculate_total_price(changeset) do
    quantity = get_field(changeset, :quantity)
    unit_price = get_field(changeset, :unit_price)

    if quantity && unit_price do
      total_price = Decimal.mult(unit_price, quantity)
      put_change(changeset, :total_price, total_price)
    else
      changeset
    end
  end
end
