output "storage_account_id" {
  description = "Resource ID of the flow log storage account."
  value       = azurerm_storage_account.flow_logs.id
}

output "flow_log_ids" {
  description = "Map of virtual network key => flow log resource ID."
  value       = { for k, v in azurerm_network_watcher_flow_log.this : k => v.id }
}
