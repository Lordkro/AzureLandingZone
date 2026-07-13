output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "vnet_name" {
  value = azurerm_virtual_network.this.name
}

output "firewall_subnet_id" {
  value = azurerm_subnet.firewall.id
}

output "gateway_subnet_id" {
  value = azurerm_subnet.gateway.id
}

output "bastion_subnet_id" {
  value = azurerm_subnet.bastion.id
}

output "shared_services_subnet_id" {
  value = azurerm_subnet.shared_services.id
}
