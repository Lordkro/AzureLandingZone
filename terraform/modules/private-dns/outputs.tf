output "zone_ids" {
  description = "Map of zone name to resource ID."
  value       = { for name, zone in azurerm_private_dns_zone.this : name => zone.id }
}
