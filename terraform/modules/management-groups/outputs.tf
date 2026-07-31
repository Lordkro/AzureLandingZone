output "intermediate_root_id" {
  description = "Resource ID of the intermediate root management group."
  value       = azurerm_management_group.intermediate_root.id
}

output "management_group_ids" {
  description = "Map of hierarchy key => management group resource ID."
  value       = local.all_groups
}

output "landing_zones_id" {
  description = "Resource ID of the Landing Zones management group — the usual policy assignment scope for workloads."
  value       = azurerm_management_group.landing_zones.id
}

output "platform_id" {
  description = "Resource ID of the Platform management group."
  value       = azurerm_management_group.platform.id
}
