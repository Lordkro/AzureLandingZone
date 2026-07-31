# ---------------------------------------------------------------------------
# Platform observability baseline:
#   1. Subscription activity log -> central Log Analytics workspace
#   2. Action group for platform notifications
#   3. Service Health / Resource Health activity log alerts
#   4. Metric alerts on the always-on platform components
# ---------------------------------------------------------------------------

# The subscription activity log is the audit trail for every control-plane
# operation. Without this setting it is only retained for 90 days and cannot be
# queried alongside resource logs.
resource "azurerm_monitor_diagnostic_setting" "activity_log" {
  name                       = "diag-activity-log"
  target_resource_id         = "/subscriptions/${var.subscription_id}"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  dynamic "enabled_log" {
    for_each = toset([
      "Administrative",
      "Security",
      "ServiceHealth",
      "Alert",
      "Recommendation",
      "Policy",
      "Autoscale",
      "ResourceHealth",
    ])
    content {
      category = enabled_log.value
    }
  }
}

# ---------------------------------------------------------------------------
# Action group
# ---------------------------------------------------------------------------

locals {
  # Action group short names are capped at 12 characters and show up as the
  # sender on SMS/email. substr() errors if the length exceeds the string, hence
  # the min().
  raw_short_name = "plat${var.short_name_suffix}"
  short_name     = substr(local.raw_short_name, 0, min(12, length(local.raw_short_name)))
}

resource "azurerm_monitor_action_group" "platform" {
  name                = "ag-platform-${var.suffix}"
  resource_group_name = var.resource_group_name
  short_name          = local.short_name
  tags                = var.tags

  dynamic "email_receiver" {
    for_each = var.notification_emails
    content {
      name                    = "email-${email_receiver.key}"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }

  dynamic "webhook_receiver" {
    for_each = var.notification_webhooks
    content {
      name                    = "webhook-${webhook_receiver.key}"
      service_uri             = webhook_receiver.value
      use_common_alert_schema = true
    }
  }
}

# ---------------------------------------------------------------------------
# Activity log alerts
# ---------------------------------------------------------------------------

resource "azurerm_monitor_activity_log_alert" "service_health" {
  name                = "alert-service-health-${var.suffix}"
  resource_group_name = var.resource_group_name
  location            = "global"
  scopes              = ["/subscriptions/${var.subscription_id}"]
  description         = "Azure service issues, planned maintenance and security advisories affecting this subscription."
  tags                = var.tags

  criteria {
    category = "ServiceHealth"

    service_health {
      events    = ["Incident", "Maintenance", "Security"]
      locations = var.service_health_locations
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.platform.id
  }
}

resource "azurerm_monitor_activity_log_alert" "resource_health" {
  name                = "alert-resource-health-${var.suffix}"
  resource_group_name = var.resource_group_name
  location            = "global"
  scopes              = ["/subscriptions/${var.subscription_id}"]
  description         = "Platform resources reporting Degraded or Unavailable health."
  tags                = var.tags

  criteria {
    category = "ResourceHealth"

    resource_health {
      current  = ["Degraded", "Unavailable"]
      previous = ["Available"]
      # Only alert on platform-initiated changes; user actions (e.g. a planned
      # stop) are expected and would otherwise be noise.
      reason = ["PlatformInitiated"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.platform.id
  }
}

# Any change to a policy assignment or role assignment is a governance event.
resource "azurerm_monitor_activity_log_alert" "governance_changes" {
  name                = "alert-governance-changes-${var.suffix}"
  resource_group_name = var.resource_group_name
  location            = "global"
  scopes              = ["/subscriptions/${var.subscription_id}"]
  description         = "Role assignment created or deleted at subscription scope."
  tags                = var.tags

  criteria {
    category       = "Administrative"
    operation_name = "Microsoft.Authorization/roleAssignments/write"
  }

  action {
    action_group_id = azurerm_monitor_action_group.platform.id
  }
}

# ---------------------------------------------------------------------------
# Metric alerts on always-on platform components
# ---------------------------------------------------------------------------

resource "azurerm_monitor_metric_alert" "firewall_health" {
  name                = "alert-firewall-health-${var.suffix}"
  resource_group_name = var.resource_group_name
  scopes              = [var.firewall_id]
  description         = "Azure Firewall health state degraded."
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Network/azureFirewalls"
    metric_name      = "FirewallHealth"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 100
  }

  action {
    action_group_id = azurerm_monitor_action_group.platform.id
  }
}

# SNAT exhaustion silently drops outbound connections — the classic hub failure.
resource "azurerm_monitor_metric_alert" "firewall_snat" {
  name                = "alert-firewall-snat-${var.suffix}"
  resource_group_name = var.resource_group_name
  scopes              = [var.firewall_id]
  description         = "Azure Firewall SNAT port utilisation above 95% — add public IPs."
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Network/azureFirewalls"
    metric_name      = "SNATPortUtilization"
    aggregation      = "Maximum"
    operator         = "GreaterThan"
    threshold        = 95
  }

  action {
    action_group_id = azurerm_monitor_action_group.platform.id
  }
}

resource "azurerm_monitor_metric_alert" "app_gateway_unhealthy_hosts" {
  count = var.app_gateway_id == null ? 0 : 1

  name                = "alert-appgw-unhealthy-hosts-${var.suffix}"
  resource_group_name = var.resource_group_name
  scopes              = [var.app_gateway_id]
  description         = "Application Gateway backend hosts failing health probes."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Network/applicationGateways"
    metric_name      = "UnhealthyHostCount"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 0
  }

  action {
    action_group_id = azurerm_monitor_action_group.platform.id
  }
}
