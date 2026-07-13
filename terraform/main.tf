data "azurerm_client_config" "current" {}

locals {
  suffix = "${var.prefix}-${var.environment}-${var.location_short}"
  tags   = merge(var.tags, { environment = var.environment })
}

# ---------------------------------------------------------------------------
# Resource groups
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "hub" {
  name     = "rg-hub-${local.suffix}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "spoke" {
  name     = "rg-spoke-${local.suffix}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "management" {
  name     = "rg-mgmt-${local.suffix}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "security" {
  name     = "rg-sec-${local.suffix}"
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------------------
# Management: Log Analytics + data collection
# ---------------------------------------------------------------------------

module "log_analytics" {
  source = "./modules/log-analytics"

  name                = "log-${local.suffix}"
  resource_group_name = azurerm_resource_group.management.name
  location            = var.location
  retention_in_days   = var.log_retention_days
  tags                = local.tags
}

# ---------------------------------------------------------------------------
# Hub networking
# ---------------------------------------------------------------------------

module "hub_network" {
  source = "./modules/hub-network"

  name                       = "vnet-hub-${local.suffix}"
  resource_group_name        = azurerm_resource_group.hub.name
  location                   = var.location
  address_space              = var.hub_address_space
  firewall_subnet_prefix     = var.hub_subnets.firewall
  gateway_subnet_prefix      = var.hub_subnets.gateway
  bastion_subnet_prefix      = var.hub_subnets.bastion
  shared_services_prefix     = var.hub_subnets.shared_services
  log_analytics_workspace_id = module.log_analytics.workspace_id
  tags                       = local.tags
}

module "firewall" {
  source = "./modules/firewall"

  name                       = "afw-${local.suffix}"
  resource_group_name        = azurerm_resource_group.hub.name
  location                   = var.location
  sku_tier                   = var.firewall_sku_tier
  subnet_id                  = module.hub_network.firewall_subnet_id
  spoke_address_space        = var.spoke_address_space
  log_analytics_workspace_id = module.log_analytics.workspace_id
  tags                       = local.tags
}

module "bastion" {
  source = "./modules/bastion"

  name                       = "bas-${local.suffix}"
  resource_group_name        = azurerm_resource_group.hub.name
  location                   = var.location
  subnet_id                  = module.hub_network.bastion_subnet_id
  log_analytics_workspace_id = module.log_analytics.workspace_id
  tags                       = local.tags
}

module "vpn_gateway" {
  source = "./modules/vpn-gateway"

  name                       = "vgw-${local.suffix}"
  resource_group_name        = azurerm_resource_group.hub.name
  location                   = var.location
  sku                        = var.vpn_gateway_sku
  subnet_id                  = module.hub_network.gateway_subnet_id
  vpn_client_address_space   = var.vpn_client_address_space
  onprem_gateways            = var.onprem_gateways
  onprem_shared_keys         = var.onprem_shared_keys
  log_analytics_workspace_id = module.log_analytics.workspace_id
  tags                       = local.tags
}

module "private_dns" {
  source = "./modules/private-dns"

  zones               = var.private_dns_zones
  resource_group_name = azurerm_resource_group.hub.name
  virtual_network_ids = {
    hub   = module.hub_network.vnet_id
    spoke = module.spoke_network.vnet_id
  }
  tags = local.tags
}

# ---------------------------------------------------------------------------
# Spoke networking (peered to hub, egress via firewall)
# ---------------------------------------------------------------------------

module "spoke_network" {
  source = "./modules/spoke-network"

  name                       = "vnet-spoke-${local.suffix}"
  resource_group_name        = azurerm_resource_group.spoke.name
  location                   = var.location
  address_space              = var.spoke_address_space
  workload_subnet_prefix     = var.spoke_subnets.workload
  app_gateway_subnet_prefix  = var.spoke_subnets.app_gateway
  private_endpoints_prefix   = var.spoke_subnets.private_endpoints
  hub_vnet_id                = module.hub_network.vnet_id
  hub_vnet_name              = module.hub_network.vnet_name
  hub_resource_group_name    = azurerm_resource_group.hub.name
  firewall_private_ip        = module.firewall.private_ip_address
  log_analytics_workspace_id = module.log_analytics.workspace_id
  tags                       = local.tags

  # Spokes must not forward traffic through the hub before the gateway exists.
  depends_on = [module.vpn_gateway]
}

# ---------------------------------------------------------------------------
# Security & governance
# ---------------------------------------------------------------------------

module "defender" {
  source = "./modules/defender"

  subscription_id            = data.azurerm_client_config.current.subscription_id
  plans                      = var.defender_plans
  security_contact_email     = var.security_contact_email
  log_analytics_workspace_id = module.log_analytics.workspace_id
}

module "policy" {
  source = "./modules/policy"

  subscription_id            = data.azurerm_client_config.current.subscription_id
  location                   = var.location
  allowed_locations          = var.allowed_locations
  required_tags              = var.required_tags
  log_analytics_workspace_id = module.log_analytics.workspace_id
}

module "update_manager" {
  source = "./modules/update-manager"

  name                = "mc-${local.suffix}"
  resource_group_name = azurerm_resource_group.management.name
  location            = var.location
  maintenance_window  = var.maintenance_window
  tags                = local.tags
}

module "rbac" {
  source = "./modules/rbac"

  subscription_id = data.azurerm_client_config.current.subscription_id
  assignments     = var.rbac_assignments
}

# ---------------------------------------------------------------------------
# Shared workload services
# ---------------------------------------------------------------------------

resource "random_string" "storage_suffix" {
  length  = 6
  lower   = true
  upper   = false
  numeric = true
  special = false
}

module "key_vault" {
  source = "./modules/key-vault"

  name                       = "kv-${var.prefix}-${var.environment}-${random_string.storage_suffix.result}"
  resource_group_name        = azurerm_resource_group.security.name
  location                   = var.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  admin_object_ids           = var.key_vault_admin_object_ids
  private_endpoint_subnet_id = module.spoke_network.private_endpoints_subnet_id
  private_dns_zone_id        = module.private_dns.zone_ids["privatelink.vaultcore.azure.net"]
  log_analytics_workspace_id = module.log_analytics.workspace_id
  tags                       = local.tags
}

module "storage" {
  source = "./modules/storage"

  name                       = "st${var.prefix}${var.environment}${random_string.storage_suffix.result}"
  resource_group_name        = azurerm_resource_group.spoke.name
  location                   = var.location
  private_endpoint_subnet_id = module.spoke_network.private_endpoints_subnet_id
  private_dns_zone_id        = module.private_dns.zone_ids["privatelink.blob.core.windows.net"]
  log_analytics_workspace_id = module.log_analytics.workspace_id
  tags                       = local.tags
}

module "app_gateway" {
  source = "./modules/app-gateway"

  name                       = "agw-${local.suffix}"
  resource_group_name        = azurerm_resource_group.spoke.name
  location                   = var.location
  subnet_id                  = module.spoke_network.app_gateway_subnet_id
  autoscale_min              = var.app_gateway_capacity.min
  autoscale_max              = var.app_gateway_capacity.max
  log_analytics_workspace_id = module.log_analytics.workspace_id
  tags                       = local.tags
}
