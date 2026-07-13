resource "azurerm_role_assignment" "this" {
  for_each = var.assignments

  scope                = coalesce(each.value.scope, "/subscriptions/${var.subscription_id}")
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal_id
}
