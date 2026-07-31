output "budget_id" {
  description = "Resource ID of the subscription budget."
  value       = azurerm_consumption_budget_subscription.this.id
}
