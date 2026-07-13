resource "azurerm_security_center_subscription_pricing" "this" {
  for_each = toset(var.plans)

  tier          = "Standard"
  resource_type = each.value
}

resource "azurerm_security_center_contact" "this" {
  name                = "default"
  email               = var.security_contact_email
  alert_notifications = true
  alerts_to_admins    = true
}

# Stream Defender data (security events) to the central workspace.
resource "azurerm_security_center_workspace" "this" {
  scope        = "/subscriptions/${var.subscription_id}"
  workspace_id = var.log_analytics_workspace_id
}

# Continuous export of alerts and recommendations is configured per
# subscription in the portal or via azurerm_security_center_automation if
# integration with Sentinel/Event Hub is required.
