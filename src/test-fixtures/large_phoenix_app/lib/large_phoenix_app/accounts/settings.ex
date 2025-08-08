defmodule LargePhoenixApp.Accounts.Settings do
  @moduledoc """
  User settings and preferences management.
  Dependencies: User, Profile
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias LargePhoenixApp.Accounts.User

  schema "user_settings" do
    field :theme, :string, default: "light"
    field :language, :string, default: "en"
    field :timezone, :string, default: "UTC"
    field :email_notifications, :boolean, default: true
    field :push_notifications, :boolean, default: true
    field :marketing_emails, :boolean, default: false
    field :two_factor_enabled, :boolean, default: false
    field :privacy_level, :string, default: "public"
    field :recommendations, {:array, :string}, default: []

    belongs_to :user, User

    timestamps()
  end

  def changeset(settings, attrs) do
    settings
    |> cast(attrs, [:theme, :language, :timezone, :email_notifications,
                    :push_notifications, :marketing_emails, :two_factor_enabled,
                    :privacy_level, :recommendations])
    |> validate_inclusion(:theme, ["light", "dark", "auto"])
    |> validate_inclusion(:privacy_level, ["public", "friends", "private"])
    |> validate_length(:language, is: 2)
  end

  def update_recommendations(user_id, new_recommendations) do
    # Complex recommendation management
    case get_user_settings(user_id) do
      nil -> create_settings_with_recommendations(user_id, new_recommendations)
      settings -> merge_recommendations(settings, new_recommendations)
    end
  end

  defp get_user_settings(user_id) do
    # Simulated database lookup
    %__MODULE__{
      user_id: user_id,
      recommendations: ["Update profile", "Review security"],
      theme: "light",
      privacy_level: "public"
    }
  end

  defp create_settings_with_recommendations(user_id, recommendations) do
    %__MODULE__{
      user_id: user_id,
      recommendations: recommendations
    }
  end

  defp merge_recommendations(settings, new_recommendations) do
    # Complex merging logic that preserves important recommendations
    existing = settings.recommendations || []

    # Keep security-related recommendations
    security_recommendations = filter_security_recommendations(existing)

    # Add new recommendations but limit total count
    merged = (security_recommendations ++ new_recommendations)
             |> Enum.uniq()
             |> Enum.take(10)

    %{settings | recommendations: merged}
  end

  defp filter_security_recommendations(recommendations) do
    security_keywords = ["security", "password", "verification", "auth"]

    Enum.filter(recommendations, fn rec ->
      Enum.any?(security_keywords, &String.contains?(String.downcase(rec), &1))
    end)
  end

  def get_notification_preferences(user_id) do
    # Complex notification preference calculation
    with {:ok, settings} <- get_settings(user_id),
         {:ok, user_profile} <- get_user_profile(user_id) do

      calculate_notification_preferences(settings, user_profile)
    else
      {:error, reason} -> {:error, "Failed to get preferences: #{reason}"}
    end
  end

  defp get_settings(user_id) do
    {:ok, get_user_settings(user_id)}
  end

  defp get_user_profile(user_id) do
    # This creates a dependency on the Profile module
    case LargePhoenixApp.Accounts.Profile.get_full_profile(user_id) do
      {:ok, profile} -> {:ok, profile}
      {:error, reason} -> {:error, reason}
    end
  end

  defp calculate_notification_preferences(settings, profile) do
    # Complex calculation based on user behavior and settings
    base_preferences = %{
      email: settings.email_notifications,
      push: settings.push_notifications,
      marketing: settings.marketing_emails
    }

    # Adjust based on user activity level
    activity_adjustments = case profile.activity_history.total_sessions do
      sessions when sessions > 100 -> %{frequency: "high", priority: "all"}
      sessions when sessions > 50 -> %{frequency: "medium", priority: "important"}
      _ -> %{frequency: "low", priority: "critical"}
    end

    {:ok, Map.merge(base_preferences, activity_adjustments)}
  end
end
