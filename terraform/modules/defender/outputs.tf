output "enabled_plans" {
  value = [for p in azurerm_security_center_subscription_pricing.this : p.resource_type]
}
