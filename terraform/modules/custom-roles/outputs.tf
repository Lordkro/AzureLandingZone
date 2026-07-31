output "role_definition_ids" {
  description = "Map of role key => role definition resource ID."
  value       = { for k, v in azurerm_role_definition.this : k => v.role_definition_resource_id }
}

output "role_names" {
  description = "Map of role key => display name, for use in rbac_assignments."
  value       = { for k, v in azurerm_role_definition.this : k => v.name }
}
