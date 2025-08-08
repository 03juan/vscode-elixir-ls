defmodule LargePhoenixApp.Notifications.EmailService do
  @moduledoc """
  Email notification service with complex templating and delivery logic.

  This module demonstrates cross-module coordination and would benefit
  from IDE Coordinator during debugging of email delivery workflows.

  Dependencies: User, Order, NotificationTemplate, DeliveryTracker
  """

  alias LargePhoenixApp.Accounts.User
  alias LargePhoenixApp.Orders.Order
  alias LargePhoenixApp.Notifications.{NotificationTemplate, DeliveryTracker}

  @delivery_providers ["sendgrid", "mailgun", "ses"]

  def send_operation_notification(user, operation_type) do
    # Complex notification logic that coordinates with multiple modules
    with {:ok, template} <- get_notification_template(operation_type),
         {:ok, personalized_content} <- personalize_content(template, user),
         {:ok, delivery_config} <- get_delivery_configuration(user),
         {:ok, _delivery_id} <- deliver_email(user, personalized_content, delivery_config) do

      {:ok, "Notification sent successfully"}
    else
      {:error, reason} -> {:error, "Failed to send notification: #{reason}"}
    end
  end

  def send_order_confirmation(order) do
    # Order confirmation email with complex business logic
    with {:ok, user} <- get_order_user(order),
         {:ok, order_details} <- prepare_order_details(order),
         {:ok, template} <- get_notification_template("order_confirmation"),
         {:ok, personalized_content} <- personalize_order_content(template, user, order_details),
         {:ok, delivery_config} <- get_delivery_configuration(user),
         {:ok, delivery_id} <- deliver_email(user, personalized_content, delivery_config) do

      # Track delivery for analytics
      DeliveryTracker.track_email_sent(delivery_id, user.id, "order_confirmation")
      {:ok, delivery_id}
    else
      {:error, reason} -> {:error, "Failed to send order confirmation: #{reason}"}
    end
  end

  defp get_notification_template(template_type) do
    # Complex template selection based on user preferences and A/B testing
    case NotificationTemplate.get_active_template(template_type) do
      nil -> {:error, "Template not found for type: #{template_type}"}
      template -> validate_template(template)
    end
  end

  defp validate_template(template) do
    # Template validation with complex business rules
    required_fields = ["subject", "body", "template_version"]

    missing_fields = Enum.filter(required_fields, fn field ->
      not Map.has_key?(template.content, field)
    end)

    if Enum.empty?(missing_fields) do
      {:ok, template}
    else
      {:error, "Template missing required fields: #{Enum.join(missing_fields, ", ")}"}
    end
  end

  defp personalize_content(template, user) do
    # Complex personalization engine
    with {:ok, user_profile} <- get_user_profile(user),
         {:ok, user_preferences} <- get_user_preferences(user),
         {:ok, personalized_data} <- build_personalization_data(user, user_profile, user_preferences) do

      personalized_content = apply_personalization(template.content, personalized_data)
      {:ok, personalized_content}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp personalize_order_content(template, user, order_details) do
    # Order-specific personalization with complex formatting
    with {:ok, user_profile} <- get_user_profile(user),
         {:ok, formatted_order} <- format_order_details(order_details),
         {:ok, shipping_info} <- get_shipping_information(order_details),
         {:ok, payment_summary} <- get_payment_summary(order_details) do

      personalization_data = %{
        user_name: get_user_display_name(user, user_profile),
        order_number: order_details.order_number,
        order_total: format_currency(order_details.total_amount),
        order_items: formatted_order.items,
        shipping_address: shipping_info.address,
        estimated_delivery: shipping_info.estimated_delivery,
        payment_method: payment_summary.method_display
      }

      personalized_content = apply_personalization(template.content, personalization_data)
      {:ok, personalized_content}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_order_user(order) do
    # This creates dependency back to User module
    case order.user_id do
      nil -> {:error, "Order has no associated user"}
      user_id ->
        user = %User{id: user_id, email: "test@example.com", role: "user"}
        {:ok, user}
    end
  end

  defp prepare_order_details(order) do
    # Complex order detail preparation that coordinates with Order module
    with {:ok, order_totals} <- Order.calculate_order_totals(order),
         {:ok, order_items} <- get_formatted_order_items(order),
         {:ok, delivery_info} <- calculate_delivery_estimates(order) do

      order_details = Map.merge(order, %{
        totals: order_totals,
        formatted_items: order_items,
        delivery_estimates: delivery_info
      })

      {:ok, order_details}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_formatted_order_items(order) do
    # Format order items for email display
    items = [
      %{name: "Wireless Headphones", quantity: 2, unit_price: "$29.99", total: "$59.98"},
      %{name: "Bluetooth Speaker", quantity: 1, unit_price: "$49.99", total: "$49.99"}
    ]

    {:ok, items}
  end

  defp calculate_delivery_estimates(order) do
    # Complex delivery estimation that might coordinate with shipping providers
    estimated_delivery = NaiveDateTime.utc_now() |> NaiveDateTime.add(7, :day)

    {:ok, %{
      estimated_delivery: estimated_delivery,
      shipping_method: "Standard Shipping",
      tracking_available: true
    }}
  end

  defp get_user_profile(user) do
    # Coordinate with Profile module
    case LargePhoenixApp.Accounts.Profile.get_full_profile(user.id) do
      {:ok, profile} -> {:ok, profile}
      {:error, _} -> {:ok, %{first_name: "Valued", last_name: "Customer"}}
    end
  end

  defp get_user_preferences(user) do
    # Coordinate with Settings module
    case LargePhoenixApp.Accounts.Settings.get_notification_preferences(user.id) do
      {:ok, preferences} -> {:ok, preferences}
      {:error, _} -> {:ok, %{email: true, frequency: "medium"}}
    end
  end

  defp build_personalization_data(user, profile, preferences) do
    # Complex personalization data building
    personalization_data = %{
      user_email: user.email,
      user_name: get_user_display_name(user, profile),
      notification_frequency: preferences.frequency,
      account_type: user.role,
      personalization_level: determine_personalization_level(user, profile, preferences)
    }

    {:ok, personalization_data}
  end

  defp get_user_display_name(user, profile) do
    case {profile[:first_name], profile[:last_name]} do
      {first, last} when is_binary(first) and is_binary(last) -> "#{first} #{last}"
      {first, _} when is_binary(first) -> first
      _ -> String.split(user.email, "@") |> List.first() |> String.capitalize()
    end
  end

  defp determine_personalization_level(user, profile, preferences) do
    # Complex personalization level calculation
    case {user.role, profile[:activity_level], preferences[:frequency]} do
      {"admin", _, _} -> :high
      {"user", "high", "high"} -> :high
      {"user", "medium", _} -> :medium
      {"user", "low", "low"} -> :minimal
      _ -> :standard
    end
  end

  defp apply_personalization(template_content, personalization_data) do
    # Complex template rendering with personalization
    Enum.reduce(personalization_data, template_content, fn {key, value}, content ->
      placeholder = "{{#{key}}}"
      String.replace(content, placeholder, to_string(value))
    end)
  end

  defp format_order_details(order_details) do
    # Complex order formatting for email display
    formatted_items = Enum.map(order_details.formatted_items, fn item ->
      %{
        name: item.name,
        quantity: item.quantity,
        unit_price: item.unit_price,
        total: item.total,
        image_url: get_product_image_url(item.name)
      }
    end)

    {:ok, %{items: formatted_items}}
  end

  defp get_product_image_url(_product_name) do
    # Placeholder image URL generation
    "https://example.com/product-image.jpg"
  end

  defp get_shipping_information(order_details) do
    # Complex shipping information compilation
    {:ok, %{
      address: "123 Main St, City, State 12345",
      estimated_delivery: order_details.delivery_estimates.estimated_delivery,
      shipping_method: order_details.delivery_estimates.shipping_method
    }}
  end

  defp get_payment_summary(order_details) do
    # Payment summary formatting
    {:ok, %{
      method_display: "Credit Card ending in 1234",
      total_charged: format_currency(order_details.totals.total_amount)
    }}
  end

  defp format_currency(amount) do
    # Currency formatting
    "$#{Decimal.to_string(amount)}"
  end

  defp get_delivery_configuration(user) do
    # Complex delivery provider selection based on user location and preferences
    with {:ok, user_location} <- get_user_location(user),
         {:ok, provider} <- select_optimal_provider(user_location),
         {:ok, config} <- get_provider_configuration(provider) do

      {:ok, config}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_user_location(user) do
    # User location determination (simplified)
    {:ok, %{country: "US", region: "west"}}
  end

  defp select_optimal_provider(location) do
    # Provider selection based on location and performance metrics
    provider = case location.region do
      "west" -> "sendgrid"
      "east" -> "mailgun"
      _ -> "ses"
    end

    {:ok, provider}
  end

  defp get_provider_configuration(provider) do
    # Provider-specific configuration
    config = case provider do
      "sendgrid" -> %{api_key: "sg_key", endpoint: "https://api.sendgrid.com"}
      "mailgun" -> %{api_key: "mg_key", endpoint: "https://api.mailgun.net"}
      "ses" -> %{access_key: "aws_key", region: "us-west-2"}
    end

    {:ok, config}
  end

  defp deliver_email(user, content, delivery_config) do
    # Complex email delivery with retry logic and monitoring
    delivery_id = generate_delivery_id()

    # Simulate email delivery
    case attempt_delivery(user.email, content, delivery_config) do
      {:ok, _response} ->
        {:ok, delivery_id}
      {:error, reason} ->
        # Retry logic could go here
        {:error, "Delivery failed: #{reason}"}
    end
  end

  defp attempt_delivery(email, content, delivery_config) do
    # Simulated email delivery attempt
    # In real app, this would integrate with actual email service APIs

    if String.contains?(email, "@") do
      {:ok, %{message_id: generate_delivery_id(), status: "queued"}}
    else
      {:error, "Invalid email address"}
    end
  end

  defp generate_delivery_id() do
    :crypto.strong_rand_bytes(12) |> Base.encode64()
  end
end
