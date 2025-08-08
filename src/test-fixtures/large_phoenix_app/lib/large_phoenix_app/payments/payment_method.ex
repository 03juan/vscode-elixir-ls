defmodule LargePhoenixApp.Payments.PaymentMethod do
  @moduledoc """
  Payment method management.
  Dependencies: User
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias LargePhoenixApp.Accounts.User

  @method_types ["credit_card", "paypal", "bank_transfer", "digital_wallet"]

  schema "payment_methods" do
    field :method_type, :string
    field :is_default, :boolean, default: false
    field :is_active, :boolean, default: true
    field :last_four, :string
    field :expires_at, :naive_datetime
    field :nickname, :string

    belongs_to :user, User

    timestamps()
  end

  def changeset(payment_method, attrs) do
    payment_method
    |> cast(attrs, [:method_type, :is_default, :is_active, :last_four, :expires_at, :nickname])
    |> validate_required([:method_type])
    |> validate_inclusion(:method_type, @method_types)
  end

  def get_default_for_user(user_id) do
    # Simulated default payment method lookup
    %__MODULE__{
      id: 1,
      user_id: user_id,
      method_type: "credit_card",
      is_default: true,
      is_active: true,
      last_four: "1234",
      expires_at: NaiveDateTime.utc_now() |> NaiveDateTime.add(365, :day)
    }
  end
end
