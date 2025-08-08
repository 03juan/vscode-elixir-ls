defmodule LargePhoenixApp.Payments.Payment do
  @moduledoc """
  Payment processing with complex business logic.

  Dependencies: User, Order, PaymentMethod
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias LargePhoenixApp.Accounts.User
  alias LargePhoenixApp.Orders.Order
  alias LargePhoenixApp.Payments.PaymentMethod

  @statuses ["pending", "processing", "completed", "failed", "refunded"]

  schema "payments" do
    field :amount, :decimal
    field :currency, :string, default: "USD"
    field :status, :string, default: "pending"
    field :transaction_id, :string
    field :payment_method_type, :string
    field :processed_at, :naive_datetime
    field :failure_reason, :string

    belongs_to :user, User
    belongs_to :order, Order
    belongs_to :payment_method, PaymentMethod

    timestamps()
  end

  def changeset(payment, attrs) do
    payment
    |> cast(attrs, [:amount, :currency, :status, :transaction_id,
                    :payment_method_type, :processed_at, :failure_reason])
    |> validate_required([:amount, :currency])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:amount, greater_than: 0)
  end

  def get_user_status(user_id) do
    # Complex user payment status calculation
    # This is called from User module, creating circular dependencies
    with {:ok, recent_payments} <- get_recent_payments(user_id),
         {:ok, payment_history} <- analyze_payment_history(recent_payments),
         {:ok, risk_score} <- calculate_payment_risk(user_id, payment_history) do

      determine_user_payment_status(payment_history, risk_score)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_recent_payments(user_id) do
    # Simulated recent payments lookup
    recent_payments = [
      %__MODULE__{user_id: user_id, status: "completed", amount: Decimal.new("29.99")},
      %__MODULE__{user_id: user_id, status: "completed", amount: Decimal.new("49.99")},
      %__MODULE__{user_id: user_id, status: "failed", amount: Decimal.new("15.99")}
    ]

    {:ok, recent_payments}
  end

  defp analyze_payment_history(payments) do
    # Complex payment pattern analysis
    total_payments = length(payments)
    successful_payments = Enum.count(payments, &(&1.status == "completed"))
    failed_payments = Enum.count(payments, &(&1.status == "failed"))

    success_rate = if total_payments > 0, do: successful_payments / total_payments, else: 0

    total_amount = Enum.reduce(payments, Decimal.new("0"), fn payment, acc ->
      if payment.status == "completed" do
        Decimal.add(acc, payment.amount)
      else
        acc
      end
    end)

    {:ok, %{
      total_payments: total_payments,
      successful_payments: successful_payments,
      failed_payments: failed_payments,
      success_rate: success_rate,
      total_amount: total_amount
    }}
  end

  defp calculate_payment_risk(user_id, payment_history) do
    # Risk calculation that coordinates with User module
    user = get_user_info(user_id)

    base_risk = case payment_history.success_rate do
      rate when rate >= 0.9 -> 0.1
      rate when rate >= 0.7 -> 0.3
      rate when rate >= 0.5 -> 0.5
      _ -> 0.8
    end

    # Adjust risk based on user factors
    user_risk_adjustment = calculate_user_risk_factors(user)
    final_risk = min(base_risk + user_risk_adjustment, 1.0)

    {:ok, final_risk}
  end

  defp get_user_info(user_id) do
    # This creates dependency back to User module
    %User{id: user_id, role: "user", active: true, login_count: 50}
  end

  defp calculate_user_risk_factors(user) do
    case {user.role, user.active, user.login_count} do
      {"admin", true, _} -> -0.2
      {"user", true, count} when count > 100 -> -0.1
      {"user", true, count} when count > 50 -> 0.0
      {"user", true, _} -> 0.1
      {"user", false, _} -> 0.3
      _ -> 0.5
    end
  end

  defp determine_user_payment_status(payment_history, risk_score) do
    cond do
      risk_score <= 0.2 && payment_history.success_rate >= 0.9 -> {:ok, :excellent}
      risk_score <= 0.4 && payment_history.success_rate >= 0.7 -> {:ok, :good}
      risk_score <= 0.6 && payment_history.success_rate >= 0.5 -> {:ok, :fair}
      risk_score <= 0.8 -> {:ok, :poor}
      true -> {:ok, :bad}
    end
  end

  def process_order_payment(order) do
    # Complex payment processing pipeline
    # Perfect scenario for coordinated debugging across modules
    with {:ok, payment_amount} <- calculate_payment_amount(order),
         {:ok, payment_method} <- select_payment_method(order.user_id),
         {:ok, payment} <- create_payment_record(order, payment_amount, payment_method),
         {:ok, processed_payment} <- process_with_gateway(payment, payment_method) do

      {:ok, processed_payment}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp calculate_payment_amount(order) do
    # This coordinates with Order module for total calculation
    case Order.calculate_order_totals(order) do
      {:ok, totals} -> {:ok, totals.total_amount}
      {:error, reason} -> {:error, "Failed to calculate payment amount: #{reason}"}
    end
  end

  defp select_payment_method(user_id) do
    # Complex payment method selection logic
    case PaymentMethod.get_default_for_user(user_id) do
      nil -> {:error, "No payment method found"}
      payment_method -> validate_payment_method(payment_method)
    end
  end

  defp validate_payment_method(payment_method) do
    # Payment method validation that might coordinate with external services
    case payment_method.method_type do
      "credit_card" -> validate_credit_card(payment_method)
      "paypal" -> validate_paypal_account(payment_method)
      "bank_transfer" -> validate_bank_account(payment_method)
      _ -> {:error, "Unsupported payment method"}
    end
  end

  defp validate_credit_card(payment_method) do
    # Complex credit card validation
    if payment_method.is_active && payment_method.expires_at > NaiveDateTime.utc_now() do
      {:ok, payment_method}
    else
      {:error, "Credit card is expired or inactive"}
    end
  end

  defp validate_paypal_account(payment_method) do
    # PayPal account validation
    {:ok, payment_method}
  end

  defp validate_bank_account(payment_method) do
    # Bank account validation
    {:ok, payment_method}
  end

  defp create_payment_record(order, amount, payment_method) do
    payment = %__MODULE__{
      user_id: order.user_id,
      order_id: order.id,
      payment_method_id: payment_method.id,
      amount: amount,
      payment_method_type: payment_method.method_type,
      status: "pending"
    }

    {:ok, payment}
  end

  defp process_with_gateway(payment, payment_method) do
    # Gateway processing that coordinates with external services
    case payment_method.method_type do
      "credit_card" -> process_credit_card_payment(payment, payment_method)
      "paypal" -> process_paypal_payment(payment, payment_method)
      "bank_transfer" -> process_bank_transfer(payment, payment_method)
    end
  end

  defp process_credit_card_payment(payment, _payment_method) do
    # Simulated credit card processing
    # This would integrate with external payment gateways
    transaction_id = generate_transaction_id()

    processed_payment = %{payment |
      status: "completed",
      transaction_id: transaction_id,
      processed_at: NaiveDateTime.utc_now()
    }

    {:ok, processed_payment}
  end

  defp process_paypal_payment(payment, _payment_method) do
    # Simulated PayPal processing
    transaction_id = generate_transaction_id()

    processed_payment = %{payment |
      status: "completed",
      transaction_id: transaction_id,
      processed_at: NaiveDateTime.utc_now()
    }

    {:ok, processed_payment}
  end

  defp process_bank_transfer(payment, _payment_method) do
    # Simulated bank transfer processing
    processed_payment = %{payment |
      status: "processing",
      processed_at: NaiveDateTime.utc_now()
    }

    {:ok, processed_payment}
  end

  defp generate_transaction_id() do
    :crypto.strong_rand_bytes(16) |> Base.encode64()
  end
end
