output "bastion_id" {
  value = azurerm_bastion_host.this.id
}

output "dns_name" {
  value = azurerm_bastion_host.this.dns_name
}
