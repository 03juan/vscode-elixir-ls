defmodule LargePhoenixApp.Inventory.Product do
  @moduledoc """
  Product management with complex business logic.
  Dependencies: Category, Stock, Variant
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias LargePhoenixApp.Inventory.{Category, Stock, Variant}

  schema "products" do
    field :name, :string
    field :description, :string
    field :sku, :string
    field :price, :decimal
    field :cost, :decimal
    field :weight, :float
    field :dimensions, :map
    field :is_active, :boolean, default: true
    field :is_digital, :boolean, default: false

    belongs_to :category, Category
    has_many :variants, Variant
    has_one :stock, Stock

    timestamps()
  end

  def changeset(product, attrs) do
    product
    |> cast(attrs, [:name, :description, :sku, :price, :cost, :weight, :dimensions,
                    :is_active, :is_digital, :category_id])
    |> validate_required([:name, :sku, :price])
    |> validate_number(:price, greater_than: 0)
    |> validate_number(:weight, greater_than_or_equal_to: 0)
    |> unique_constraint(:sku)
  end

  def get_by_id(product_id) do
    # Simulated product lookup with complex business logic
    case product_id do
      100 ->
        {:ok, %__MODULE__{
          id: 100,
          name: "Wireless Headphones",
          sku: "WH-001",
          price: Decimal.new("29.99"),
          cost: Decimal.new("15.00"),
          weight: 0.5,
          is_active: true,
          category_id: 1
        }}
      101 ->
        {:ok, %__MODULE__{
          id: 101,
          name: "Bluetooth Speaker",
          sku: "BS-001",
          price: Decimal.new("49.99"),
          cost: Decimal.new("25.00"),
          weight: 1.2,
          is_active: true,
          category_id: 1
        }}
      _ ->
        {:error, "Product not found"}
    end
  end

  def get_current_price(product) do
    # Complex pricing logic that might coordinate with external services
    base_price = product.price

    # Apply dynamic pricing adjustments
    with {:ok, demand_multiplier} <- calculate_demand_multiplier(product),
         {:ok, inventory_adjustment} <- calculate_inventory_adjustment(product),
         {:ok, seasonal_adjustment} <- calculate_seasonal_adjustment(product) do

      final_price = base_price
                   |> Decimal.mult(demand_multiplier)
                   |> Decimal.mult(inventory_adjustment)
                   |> Decimal.mult(seasonal_adjustment)
                   |> Decimal.round(2)

      final_price
    else
      _error -> base_price
    end
  end

  defp calculate_demand_multiplier(product) do
    # Complex demand calculation that might coordinate with analytics
    recent_sales = get_recent_sales_count(product.id)

    multiplier = case recent_sales do
      count when count > 100 -> Decimal.new("1.1")  # High demand, increase price
      count when count > 50 -> Decimal.new("1.05")
      count when count < 10 -> Decimal.new("0.95")  # Low demand, decrease price
      _ -> Decimal.new("1.0")
    end

    {:ok, multiplier}
  end

  defp calculate_inventory_adjustment(product) do
    # Adjustment based on current stock levels
    case Stock.get_available_quantity(product.id) do
      quantity when quantity < 10 -> {:ok, Decimal.new("1.05")}  # Low stock, increase price
      quantity when quantity > 100 -> {:ok, Decimal.new("0.98")} # High stock, decrease price
      _ -> {:ok, Decimal.new("1.0")}
    end
  end

  defp calculate_seasonal_adjustment(_product) do
    # Seasonal pricing adjustments
    current_month = Date.utc_today().month

    adjustment = case current_month do
      month when month in [11, 12] -> Decimal.new("1.1")  # Holiday season
      month when month in [6, 7, 8] -> Decimal.new("1.05") # Summer season
      _ -> Decimal.new("1.0")
    end

    {:ok, adjustment}
  end

  defp get_recent_sales_count(product_id) do
    # Simulated recent sales lookup
    case product_id do
      100 -> 75
      101 -> 120
      _ -> 25
    end
  end

  def get_weight(product_id) do
    # Weight lookup for shipping calculations
    case get_by_id(product_id) do
      {:ok, product} -> product.weight
      {:error, _} -> 0.0
    end
  end

  def calculate_profit_margin(product) do
    # Complex profit margin calculation
    current_price = get_current_price(product)

    with {:ok, total_cost} <- calculate_total_cost(product),
         {:ok, fees} <- calculate_fees(current_price),
         {:ok, taxes} <- calculate_taxes(current_price) do

      net_revenue = Decimal.sub(current_price, Decimal.add(fees, taxes))
      profit = Decimal.sub(net_revenue, total_cost)
      margin = Decimal.div(profit, current_price) |> Decimal.mult(100)

      {:ok, %{
        profit: profit,
        margin_percentage: margin,
        total_cost: total_cost,
        net_revenue: net_revenue
      }}
    else
      {:error, reason} -> {:error, "Failed to calculate profit margin: #{reason}"}
    end
  end

  defp calculate_total_cost(product) do
    # Total cost including base cost, storage, handling
    base_cost = product.cost
    storage_cost = calculate_storage_cost(product)
    handling_cost = calculate_handling_cost(product)

    total_cost = base_cost
                |> Decimal.add(storage_cost)
                |> Decimal.add(handling_cost)

    {:ok, total_cost}
  end

  defp calculate_storage_cost(product) do
    # Storage cost based on product dimensions and weight
    volume = calculate_volume(product.dimensions)
    storage_rate = Decimal.new("0.10")  # $0.10 per cubic foot per month

    Decimal.mult(volume, storage_rate)
  end

  defp calculate_volume(dimensions) when is_map(dimensions) do
    length = Map.get(dimensions, "length", 1.0)
    width = Map.get(dimensions, "width", 1.0)
    height = Map.get(dimensions, "height", 1.0)

    Decimal.new(to_string(length * width * height))
  end

  defp calculate_volume(_), do: Decimal.new("1.0")

  defp calculate_handling_cost(product) do
    # Handling cost based on weight and fragility
    base_handling = Decimal.mult(Decimal.new(to_string(product.weight)), Decimal.new("0.50"))

    fragility_multiplier = if product.is_digital, do: Decimal.new("0"), else: Decimal.new("1")

    Decimal.mult(base_handling, fragility_multiplier)
  end

  defp calculate_fees(price) do
    # Platform and processing fees
    platform_fee = Decimal.mult(price, Decimal.new("0.03"))  # 3% platform fee
    processing_fee = Decimal.new("0.30")  # $0.30 processing fee

    {:ok, Decimal.add(platform_fee, processing_fee)}
  end

  defp calculate_taxes(price) do
    # Sales tax calculation (simplified)
    tax_rate = Decimal.new("0.08")  # 8% sales tax
    tax_amount = Decimal.mult(price, tax_rate)

    {:ok, tax_amount}
  end
end
