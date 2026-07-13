output "workspace_id" {
  description = "Resource ID of the workspace."
  value       = azurerm_log_analytics_workspace.this.id
}

output "workspace_customer_id" {
  description = "Workspace (customer) GUID."
  value       = azurerm_log_analytics_workspace.this.workspace_id
}

output "vm_data_collection_rule_id" {
  description = "Resource ID of the VM data collection rule."
  value       = azurerm_monitor_data_collection_rule.vm.id
}
