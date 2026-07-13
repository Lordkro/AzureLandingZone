resource "azurerm_private_dns_zone" "this" {
  for_each = toset(var.zones)

  name                = each.value
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

locals {
  zone_vnet_links = {
    for pair in setproduct(var.zones, keys(var.virtual_network_ids)) :
    "${pair[0]}|${pair[1]}" => {
      zone = pair[0]
      vnet = pair[1]
    }
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = local.zone_vnet_links

  name                  = "link-${each.value.vnet}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this[each.value.zone].name
  virtual_network_id    = var.virtual_network_ids[each.value.vnet]
  registration_enabled  = false
  tags                  = var.tags
}
