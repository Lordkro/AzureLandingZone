output "app_gateway_id" {
  value = azurerm_application_gateway.this.id
}

output "public_ip_address" {
  value = azurerm_public_ip.this.ip_address
}

output "waf_policy_id" {
  value = azurerm_web_application_firewall_policy.this.id
}
