defmodule LargePhoenixApp.Accounts.Profile do
  @moduledoc """
  User profile management with behavior tracking.
  Dependencies: User
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias LargePhoenixApp.Accounts.User

  schema "profiles" do
    field :first_name, :string
    field :last_name, :string
    field :bio, :string
    field :avatar_url, :string
    field :phone, :string
    field :date_of_birth, :date
    field :behavior_score, :float, default: 0.0
    field :activity_level, :string, default: "low"

    belongs_to :user, User

    timestamps()
  end

  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:first_name, :last_name, :bio, :avatar_url, :phone, :date_of_birth])
    |> validate_required([:first_name, :last_name])
    |> validate_length(:first_name, min: 1, max: 50)
    |> validate_length(:last_name, min: 1, max: 50)
    |> validate_length(:bio, max: 500)
  end

  def update_behavior_metrics(user_id, behavior_data) do
    # Complex behavior analysis that coordinates with User module
    activity_level = determine_activity_level(behavior_data.behavior_score)

    # This is a good place for a breakpoint during debugging
    case get_profile_by_user_id(user_id) do
      nil -> create_profile_with_metrics(user_id, behavior_data, activity_level)
      profile -> update_existing_profile_metrics(profile, behavior_data, activity_level)
    end
  end

  defp get_profile_by_user_id(user_id) do
    # Simulated database lookup
    %__MODULE__{user_id: user_id, behavior_score: 0.0, activity_level: "low"}
  end

  defp create_profile_with_metrics(user_id, behavior_data, activity_level) do
    %__MODULE__{
      user_id: user_id,
      behavior_score: behavior_data.behavior_score,
      activity_level: activity_level
    }
  end

  defp update_existing_profile_metrics(profile, behavior_data, activity_level) do
    %{profile |
      behavior_score: behavior_data.behavior_score,
      activity_level: activity_level
    }
  end

  defp determine_activity_level(behavior_score) do
    cond do
      behavior_score >= 50 -> "high"
      behavior_score >= 20 -> "medium"
      true -> "low"
    end
  end

  def get_full_profile(user_id) do
    # Complex profile aggregation from multiple sources
    with {:ok, base_profile} <- get_base_profile(user_id),
         {:ok, behavior_metrics} <- get_behavior_metrics(user_id),
         {:ok, activity_history} <- get_activity_history(user_id) do

      {:ok, merge_profile_data(base_profile, behavior_metrics, activity_history)}
    else
      {:error, reason} -> {:error, "Failed to load profile: #{reason}"}
    end
  end

  defp get_base_profile(user_id) do
    {:ok, get_profile_by_user_id(user_id)}
  end

  defp get_behavior_metrics(user_id) do
    # This would typically query behavior tracking tables
    {:ok, %{score: 25.5, trend: "increasing", last_updated: DateTime.utc_now()}}
  end

  defp get_activity_history(user_id) do
    # This would query activity logs
    {:ok, %{total_sessions: 45, avg_session_length: 12.5, last_activity: DateTime.utc_now()}}
  end

  defp merge_profile_data(base_profile, behavior_metrics, activity_history) do
    # Complex data merging logic that would benefit from debugging
    Map.merge(base_profile, %{
      behavior_metrics: behavior_metrics,
      activity_history: activity_history,
      computed_at: DateTime.utc_now()
    })
  end
end
