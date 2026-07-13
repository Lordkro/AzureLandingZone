output "gateway_id" {
  value = azurerm_virtual_network_gateway.this.id
}

output "public_ip_address" {
  value = azurerm_public_ip.this.ip_address
}
