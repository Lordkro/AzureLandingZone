data "azurerm_client_config" "current" {}

locals {
  suffix             = "${var.prefix}-${var.environment}-${var.location_short}"
  tags               = merge(var.tags, { environment = var.environment })
  subscription_scope = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"

  # Emails that receive platform alerts. The security contact is always
  # included so Defender and Azure Monitor notifications land in the same place.
  alert_emails = distinct(concat([var.security_contact_email], var.platform_alert_emails))

  # one() yields null for a disabled (count = 0) module, which coalesce then
  # falls back from. Indexing with [0] behind a conditional is not safe here —
  # Terraform still evaluates the index.
  custom_role_scope = coalesce(
    one(module.management_groups[*].intermediate_root_id),
    local.subscription_scope,
  )
}

# ---------------------------------------------------------------------------
# Management group hierarchy (optional — needs Tenant Root Group permissions)
# ---------------------------------------------------------------------------

module "management_groups" {
  source = "./modules/management-groups"
  count  = var.enable_management_groups ? 1 : 0

  prefix                     = var.prefix
  display_name               = var.management_group_display_name
  parent_management_group_id = var.parent_management_group_id
  subscription_placements = merge(
    # Place the subscription this stack deploys into unless the caller overrode it.
    var.management_group_subscription_placements,
    var.management_group_placement_for_this_subscription == null ? {} : {
      (data.azurerm_client_config.current.subscription_id) = var.management_group_placement_for_this_subscription
    },
  )
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

# Platform resource groups should not be deletable by accident — a deleted hub
# takes every spoke's egress path with it. Terraform removes the lock before it
# destroys the group, so this does not block a deliberate `terraform destroy`.
resource "azurerm_management_lock" "platform_resource_groups" {
  for_each = var.enable_resource_locks ? {
    hub        = azurerm_resource_group.hub.id
    management = azurerm_resource_group.management.id
    security   = azurerm_resource_group.security.id
  } : {}

  name       = "lock-${each.key}-no-delete"
  scope      = each.value
  lock_level = "CanNotDelete"
  notes      = "Platform resource group — managed by Terraform. Remove the lock deliberately before deleting."
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
  daily_quota_gb      = var.log_daily_quota_gb
  tags                = local.tags
}

# ---------------------------------------------------------------------------
# DDoS Network Protection (optional — flat monthly charge covers all VNets)
# ---------------------------------------------------------------------------

resource "azurerm_network_ddos_protection_plan" "this" {
  count = var.enable_ddos_protection ? 1 : 0

  name                = "ddos-${local.suffix}"
  resource_group_name = azurerm_resource_group.hub.name
  location            = var.location
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
  ddos_protection_plan_id    = one(azurerm_network_ddos_protection_plan.this[*].id)
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
  ddos_protection_plan_id    = one(azurerm_network_ddos_protection_plan.this[*].id)
  log_analytics_workspace_id = module.log_analytics.workspace_id
  tags                       = local.tags

  # Spokes must not forward traffic through the hub before the gateway exists.
  depends_on = [module.vpn_gateway]
}

# ---------------------------------------------------------------------------
# VNet flow logs + Traffic Analytics (optional)
# ---------------------------------------------------------------------------

module "flow_logs" {
  source = "./modules/flow-logs"
  count  = var.enable_flow_logs ? 1 : 0

  resource_group_name  = azurerm_resource_group.management.name
  location             = var.location
  storage_account_name = "stfl${var.prefix}${var.environment}${random_string.storage_suffix.result}"

  virtual_network_ids = {
    hub   = module.hub_network.vnet_id
    spoke = module.spoke_network.vnet_id
  }

  network_watcher_name                = coalesce(var.network_watcher_name, "NetworkWatcher_${var.location}")
  network_watcher_resource_group_name = var.network_watcher_resource_group_name
  retention_days                      = var.flow_log_retention_days

  log_analytics_workspace_id          = module.log_analytics.workspace_id
  log_analytics_workspace_customer_id = module.log_analytics.workspace_customer_id
  log_analytics_workspace_location    = var.location

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Security & governance
# ---------------------------------------------------------------------------

module "defender" {
  source = "./modules/defender"

  subscription_id            = data.azurerm_client_config.current.subscription_id
  plans                      = var.defender_plans
  security_contact_email     = var.security_contact_email
  security_contact_phone     = var.security_contact_phone
  log_analytics_workspace_id = module.log_analytics.workspace_id
}

module "policy" {
  source = "./modules/policy"

  subscription_id              = data.azurerm_client_config.current.subscription_id
  location                     = var.location
  allowed_locations            = var.allowed_locations
  required_tags                = var.required_tags
  denied_resource_types        = var.denied_resource_types
  deny_public_ip_on_nic        = var.deny_public_ip_on_nic
  storage_public_access_effect = var.storage_public_access_effect
  deploy_azure_monitor_agent   = var.deploy_azure_monitor_agent
  data_collection_rule_id      = module.log_analytics.vm_data_collection_rule_id
}

module "update_manager" {
  source = "./modules/update-manager"

  name                = "mc-${local.suffix}"
  resource_group_name = azurerm_resource_group.management.name
  location            = var.location
  maintenance_window  = var.maintenance_window
  patch_tag_name      = var.patch_tag.name
  patch_tag_value     = var.patch_tag.value
  tags                = local.tags
}

module "custom_roles" {
  source = "./modules/custom-roles"
  count  = var.enable_custom_roles ? 1 : 0

  # Define the roles at the management group when the hierarchy exists so one
  # definition covers every subscription beneath it.
  scope             = local.custom_role_scope
  assignable_scopes = [local.custom_role_scope]
}

module "rbac" {
  source = "./modules/rbac"

  subscription_id = data.azurerm_client_config.current.subscription_id
  assignments     = var.rbac_assignments
}

# ---------------------------------------------------------------------------
# Platform observability & cost control
# ---------------------------------------------------------------------------

module "monitoring" {
  source = "./modules/monitoring"

  subscription_id            = data.azurerm_client_config.current.subscription_id
  suffix                     = local.suffix
  short_name_suffix          = var.environment
  resource_group_name        = azurerm_resource_group.management.name
  log_analytics_workspace_id = module.log_analytics.workspace_id
  notification_emails        = local.alert_emails
  notification_webhooks      = var.platform_alert_webhooks
  service_health_locations   = var.allowed_locations
  firewall_id                = module.firewall.firewall_id
  app_gateway_id             = module.app_gateway.app_gateway_id
  tags                       = local.tags
}

module "budget" {
  source = "./modules/budget"
  count  = var.monthly_budget_amount == null ? 0 : 1

  name             = "budget-${local.suffix}"
  subscription_id  = data.azurerm_client_config.current.subscription_id
  amount           = var.monthly_budget_amount
  start_date       = var.budget_start_date
  end_date         = var.budget_end_date
  contact_emails   = local.alert_emails
  action_group_ids = [module.monitoring.action_group_id]
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
