# Subscription budget with forecast and actual-spend notifications. Budgets do
# not stop spend — they are the tripwire that makes cost drift visible.
resource "azurerm_consumption_budget_subscription" "this" {
  name            = var.name
  subscription_id = "/subscriptions/${var.subscription_id}"
  amount          = var.amount
  time_grain      = var.time_grain

  time_period {
    start_date = var.start_date
    end_date   = var.end_date
  }

  # Actual spend crossing a threshold.
  dynamic "notification" {
    for_each = var.actual_thresholds
    content {
      enabled        = true
      threshold      = notification.value
      threshold_type = "Actual"
      operator       = "GreaterThanOrEqualTo"
      contact_emails = var.contact_emails
      contact_groups = var.action_group_ids
    }
  }

  # Forecast crossing a threshold — the useful one, it fires before the money
  # is gone.
  dynamic "notification" {
    for_each = var.forecast_thresholds
    content {
      enabled        = true
      threshold      = notification.value
      threshold_type = "Forecasted"
      operator       = "GreaterThanOrEqualTo"
      contact_emails = var.contact_emails
      contact_groups = var.action_group_ids
    }
  }
}
