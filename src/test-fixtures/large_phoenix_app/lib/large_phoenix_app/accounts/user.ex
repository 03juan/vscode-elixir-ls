defmodule LargePhoenixApp.Accounts.User do
  @moduledoc """
  User account management with complex business logic.

  This module demonstrates the kind of complex, interdependent code
  that benefits from coordinated debugging in the IDE Coordinator.

  Dependencies: UserToken, Profile, Settings, EmailService, Validation
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias LargePhoenixApp.Accounts.{UserToken, Profile, Settings}
  alias LargePhoenixApp.Notifications.EmailService
  alias LargePhoenixApp.Orders.Order
  alias LargePhoenixApp.Payments.Payment

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :naive_datetime
    field :role, :string, default: "user"
    field :active, :boolean, default: true
    field :last_login_at, :naive_datetime
    field :login_count, :integer, default: 0

    has_one :profile, Profile
    has_one :settings, Settings
    has_many :tokens, UserToken
    has_many :orders, Order
    has_many :payments, Payment

    timestamps()
  end

  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_email()
    |> validate_password(opts)
  end

  def login_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_required([:email, :password])
  end

  def update_login_stats(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    user
    |> change()
    |> put_change(:last_login_at, now)
    |> put_change(:login_count, user.login_count + 1)
  end

  def complex_business_logic(user, operation_type) do
    # This is a perfect place for coordinated debugging
    # IDE Coordinator should interpret this module and its dependencies
    with {:ok, validated_user} <- validate_user_operation(user, operation_type),
         {:ok, processed_data} <- process_user_data(validated_user),
         {:ok, _notification} <- EmailService.send_operation_notification(user, operation_type) do
      {:ok, processed_data}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_user_operation(user, operation_type) do
    # Complex validation that coordinates with multiple modules
    case {user.active, user.role, operation_type} do
      {false, _, _} -> {:error, "User account is inactive"}
      {true, "admin", _} -> {:ok, user}
      {true, "user", "purchase"} -> validate_purchase_eligibility(user)
      {true, "user", "profile_update"} -> {:ok, user}
      {true, _, operation} -> {:error, "Operation #{operation} not allowed for user role"}
    end
  end

  defp validate_purchase_eligibility(user) do
    # This would trigger dependency analysis to Orders and Payments modules
    recent_orders = get_recent_orders(user)
    payment_status = check_payment_status(user)

    case {length(recent_orders), payment_status} do
      {count, :good} when count < 10 -> {:ok, user}
      {count, :good} when count >= 10 -> {:error, "Too many recent orders"}
      {_, :bad} -> {:error, "Payment issues detected"}
    end
  end

  defp get_recent_orders(user) do
    # Simulated dependency on Orders module
    # IDE Coordinator should detect this cross-module dependency
    Order.get_recent_for_user(user.id)
  end

  defp check_payment_status(user) do
    # Simulated dependency on Payments module
    case Payment.get_user_status(user.id) do
      {:ok, status} -> status
      {:error, _} -> :unknown
    end
  end

  defp process_user_data(user) do
    # Complex processing that would benefit from coordinated debugging
    case analyze_user_behavior(user) do
      {:ok, behavior_data} ->
        update_user_metrics(user, behavior_data)
      {:error, reason} ->
        {:error, "Failed to process user data: #{reason}"}
    end
  end

  defp analyze_user_behavior(user) do
    # Perfect breakpoint location during debugging
    behavior_score = calculate_behavior_score(user)
    risk_assessment = assess_user_risk(user)

    {:ok, %{
      behavior_score: behavior_score,
      risk_level: risk_assessment,
      recommendations: generate_recommendations(behavior_score, risk_assessment)
    }}
  end

  defp calculate_behavior_score(user) do
    # Complex calculation that might need debugging
    base_score = user.login_count * 0.1
    recency_bonus = if recent_login?(user), do: 10, else: 0
    activity_multiplier = calculate_activity_multiplier(user)

    (base_score + recency_bonus) * activity_multiplier
  end

  defp recent_login?(user) do
    case user.last_login_at do
      nil -> false
      last_login ->
        days_since = NaiveDateTime.diff(NaiveDateTime.utc_now(), last_login, :day)
        days_since <= 7
    end
  end

  defp calculate_activity_multiplier(user) do
    cond do
      user.login_count > 100 -> 1.5
      user.login_count > 50 -> 1.2
      user.login_count > 10 -> 1.0
      true -> 0.8
    end
  end

  defp assess_user_risk(user) do
    # Risk assessment logic that coordinates with other modules
    case {user.role, user.active, recent_login?(user)} do
      {"admin", true, true} -> :low
      {"admin", true, false} -> :medium
      {"admin", false, _} -> :high
      {"user", true, true} -> :low
      {"user", true, false} -> :low
      {"user", false, _} -> :medium
    end
  end

  defp generate_recommendations(behavior_score, risk_level) do
    base_recommendations = ["Update profile", "Review security settings"]

    score_recommendations =
      if behavior_score < 5 do
        ["Increase platform engagement", "Complete onboarding"]
      else
        ["Explore advanced features", "Consider premium subscription"]
      end

    risk_recommendations =
      case risk_level do
        :high -> ["Security review required", "Account verification needed"]
        :medium -> ["Review recent activity", "Update password"]
        :low -> ["Account in good standing"]
      end

    base_recommendations ++ score_recommendations ++ risk_recommendations
  end

  defp update_user_metrics(user, behavior_data) do
    # Update various metrics - good coordination point
    Profile.update_behavior_metrics(user.id, behavior_data)
    Settings.update_recommendations(user.id, behavior_data.recommendations)
    {:ok, Map.merge(user, behavior_data)}
  end

  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> validate_length(:password, max: 72, count: :bytes)
      |> put_change(:hashed_password, hash_password(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  defp hash_password(password) do
    # Simulated password hashing
    :crypto.hash(:sha256, password) |> Base.encode64()
  end

  def valid_password?(%LargePhoenixApp.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    hash_password(password) == hashed_password
  end

  def valid_password?(_, _), do: false
end
