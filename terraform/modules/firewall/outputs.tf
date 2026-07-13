output "firewall_id" {
  value = azurerm_firewall.this.id
}

output "private_ip_address" {
  value = azurerm_firewall.this.ip_configuration[0].private_ip_address
}

output "public_ip_address" {
  value = azurerm_public_ip.this.ip_address
}

output "policy_id" {
  value = azurerm_firewall_policy.this.id
}
