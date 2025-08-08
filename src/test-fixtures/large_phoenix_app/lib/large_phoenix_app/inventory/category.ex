defmodule LargePhoenixApp.Inventory.Category do
  @moduledoc """
  Product category management.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "categories" do
    field :name, :string
    field :description, :string
    field :slug, :string
    field :is_active, :boolean, default: true
    field :sort_order, :integer, default: 0

    belongs_to :parent_category, __MODULE__
    has_many :subcategories, __MODULE__, foreign_key: :parent_category_id

    timestamps()
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :description, :slug, :is_active, :sort_order, :parent_category_id])
    |> validate_required([:name, :slug])
    |> unique_constraint(:slug)
  end
end
