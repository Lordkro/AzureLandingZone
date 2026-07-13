data "azurerm_client_config" "current" {}

locals {
  tenant_id = var.tenant_id != "" ? var.tenant_id : data.azurerm_client_config.current.tenant_id
}

resource "azurerm_public_ip" "this" {
  name                = "pip-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.zones
  tags                = var.tags
}

resource "azurerm_virtual_network_gateway" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = var.sku
  generation          = "Generation1"
  active_active       = false
  bgp_enabled         = false
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig"
    public_ip_address_id          = azurerm_public_ip.this.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = var.subnet_id
  }

  # Point-to-site with Entra ID (Azure AD) authentication.
  dynamic "vpn_client_configuration" {
    for_each = length(var.vpn_client_address_space) > 0 ? [1] : []
    content {
      address_space        = var.vpn_client_address_space
      vpn_client_protocols = ["OpenVPN"]
      vpn_auth_types       = ["AAD"]
      aad_tenant           = "https://login.microsoftonline.com/${local.tenant_id}/"
      aad_audience         = "41b23e61-6c1e-4545-b367-cd054e0ed4b4" # Azure VPN Client app ID
      aad_issuer           = "https://sts.windows.net/${local.tenant_id}/"
    }
  }
}

# ---------------------------------------------------------------------------
# Site-to-site connections
# ---------------------------------------------------------------------------

resource "azurerm_local_network_gateway" "onprem" {
  for_each = var.onprem_gateways

  name                = "lgw-${each.key}"
  resource_group_name = var.resource_group_name
  location            = var.location
  gateway_address     = each.value.gateway_address
  address_space       = each.value.address_space
  tags                = var.tags
}

resource "azurerm_virtual_network_gateway_connection" "onprem" {
  for_each = var.onprem_gateways

  name                       = "con-${each.key}"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.this.id
  local_network_gateway_id   = azurerm_local_network_gateway.onprem[each.key].id
  shared_key                 = var.onprem_shared_keys[each.key]
  connection_protocol        = "IKEv2"
  dpd_timeout_seconds        = 45
  tags                       = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  name                       = "diag-${var.name}"
  target_resource_id         = azurerm_virtual_network_gateway.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
