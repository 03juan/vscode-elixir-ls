defmodule LargePhoenixApp.Notifications.NotificationTemplate do
  @moduledoc """
  Notification template management.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "notification_templates" do
    field :name, :string
    field :template_type, :string
    field :subject, :string
    field :content, :map
    field :is_active, :boolean, default: true
    field :version, :integer, default: 1

    timestamps()
  end

  def changeset(template, attrs) do
    template
    |> cast(attrs, [:name, :template_type, :subject, :content, :is_active, :version])
    |> validate_required([:name, :template_type, :subject, :content])
  end

  def get_active_template(template_type) do
    # Simulated template lookup
    case template_type do
      "order_confirmation" ->
        %__MODULE__{
          name: "Order Confirmation",
          template_type: "order_confirmation",
          subject: "Your Order {{order_number}} has been confirmed!",
          content: %{
            "subject" => "Your Order {{order_number}} has been confirmed!",
            "body" => "Hi {{user_name}}, your order for {{order_total}} has been confirmed.",
            "template_version" => "2.1"
          },
          is_active: true
        }
      "user_operation" ->
        %__MODULE__{
          name: "User Operation Notification",
          template_type: "user_operation",
          subject: "Account Activity: {{operation_type}}",
          content: %{
            "subject" => "Account Activity: {{operation_type}}",
            "body" => "Hi {{user_name}}, we've processed your {{operation_type}} request.",
            "template_version" => "1.5"
          },
          is_active: true
        }
      _ -> nil
    end
  end
end
