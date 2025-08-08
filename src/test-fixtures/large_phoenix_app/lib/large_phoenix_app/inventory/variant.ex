defmodule LargePhoenixApp.Inventory.Variant do
  @moduledoc """
  Product variant management (size, color, etc.).
  Dependencies: Product
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias LargePhoenixApp.Inventory.Product

  schema "product_variants" do
    field :name, :string
    field :sku, :string
    field :price_adjustment, :decimal, default: Decimal.new("0")
    field :weight_adjustment, :float, default: 0.0
    field :attributes, :map

    belongs_to :product, Product

    timestamps()
  end

  def changeset(variant, attrs) do
    variant
    |> cast(attrs, [:name, :sku, :price_adjustment, :weight_adjustment, :attributes])
    |> validate_required([:name, :sku])
    |> unique_constraint(:sku)
  end
end
