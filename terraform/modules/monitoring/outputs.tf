output "action_group_id" {
  description = "Resource ID of the platform action group — reuse it for workload alerts."
  value       = azurerm_monitor_action_group.platform.id
}

output "activity_log_diagnostic_setting_id" {
  description = "Resource ID of the subscription activity log diagnostic setting."
  value       = azurerm_monitor_diagnostic_setting.activity_log.id
}
