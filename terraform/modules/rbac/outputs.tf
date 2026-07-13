output "assignment_ids" {
  value = { for k, a in azurerm_role_assignment.this : k => a.id }
}
