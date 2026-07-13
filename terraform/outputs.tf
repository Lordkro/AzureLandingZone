output "hub_vnet_id" {
  description = "Resource ID of the hub virtual network."
  value       = module.hub_network.vnet_id
}

output "spoke_vnet_id" {
  description = "Resource ID of the spoke virtual network."
  value       = module.spoke_network.vnet_id
}

output "firewall_private_ip" {
  description = "Private IP of Azure Firewall (next hop for spoke egress)."
  value       = module.firewall.private_ip_address
}

output "firewall_public_ip" {
  description = "Public IP of Azure Firewall."
  value       = module.firewall.public_ip_address
}

output "bastion_fqdn" {
  description = "DNS name of the Bastion host."
  value       = module.bastion.dns_name
}

output "vpn_gateway_public_ip" {
  description = "Public IP of the VPN gateway."
  value       = module.vpn_gateway.public_ip_address
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the central Log Analytics workspace."
  value       = module.log_analytics.workspace_id
}

output "key_vault_uri" {
  description = "URI of the platform Key Vault."
  value       = module.key_vault.vault_uri
}

output "storage_account_name" {
  description = "Name of the platform storage account."
  value       = module.storage.name
}

output "app_gateway_public_ip" {
  description = "Public IP of the Application Gateway."
  value       = module.app_gateway.public_ip_address
}

output "private_dns_zone_ids" {
  description = "Map of private DNS zone name to resource ID."
  value       = module.private_dns.zone_ids
}
