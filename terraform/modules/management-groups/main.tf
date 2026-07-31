# ---------------------------------------------------------------------------
# CAF management group hierarchy.
#
#   Tenant Root Group
#   └── <prefix> (intermediate root)
#       ├── Platform
#       │   ├── Identity
#       │   ├── Management
#       │   └── Connectivity
#       ├── Landing Zones
#       │   ├── Corp    (private / on-prem connected workloads)
#       │   └── Online  (internet-facing workloads)
#       ├── Sandbox     (loose policy, no connectivity)
#       └── Decommissioned
#
# Creating management groups requires Owner (or Management Group Contributor)
# on the Tenant Root Group. See docs/governance.md.
# ---------------------------------------------------------------------------

data "azurerm_client_config" "current" {}

locals {
  tenant_root_id = "/providers/Microsoft.Management/managementGroups/${data.azurerm_client_config.current.tenant_id}"

  # Second-level groups, keyed by the management group name suffix.
  platform_children = {
    identity     = "Identity"
    management   = "Management"
    connectivity = "Connectivity"
  }

  landing_zone_children = {
    corp   = "Corp"
    online = "Online"
  }
}

resource "azurerm_management_group" "intermediate_root" {
  name                       = "mg-${var.prefix}"
  display_name               = var.display_name
  parent_management_group_id = coalesce(var.parent_management_group_id, local.tenant_root_id)
}

resource "azurerm_management_group" "platform" {
  name                       = "mg-${var.prefix}-platform"
  display_name               = "Platform"
  parent_management_group_id = azurerm_management_group.intermediate_root.id
}

resource "azurerm_management_group" "platform_children" {
  for_each = local.platform_children

  name                       = "mg-${var.prefix}-${each.key}"
  display_name               = each.value
  parent_management_group_id = azurerm_management_group.platform.id
}

resource "azurerm_management_group" "landing_zones" {
  name                       = "mg-${var.prefix}-landingzones"
  display_name               = "Landing Zones"
  parent_management_group_id = azurerm_management_group.intermediate_root.id
}

resource "azurerm_management_group" "landing_zone_children" {
  for_each = local.landing_zone_children

  name                       = "mg-${var.prefix}-${each.key}"
  display_name               = each.value
  parent_management_group_id = azurerm_management_group.landing_zones.id
}

resource "azurerm_management_group" "sandbox" {
  name                       = "mg-${var.prefix}-sandbox"
  display_name               = "Sandbox"
  parent_management_group_id = azurerm_management_group.intermediate_root.id
}

resource "azurerm_management_group" "decommissioned" {
  name                       = "mg-${var.prefix}-decommissioned"
  display_name               = "Decommissioned"
  parent_management_group_id = azurerm_management_group.intermediate_root.id
}

# ---------------------------------------------------------------------------
# Subscription placement
# ---------------------------------------------------------------------------

locals {
  all_groups = merge(
    {
      intermediate_root = azurerm_management_group.intermediate_root.id
      platform          = azurerm_management_group.platform.id
      landingzones      = azurerm_management_group.landing_zones.id
      sandbox           = azurerm_management_group.sandbox.id
      decommissioned    = azurerm_management_group.decommissioned.id
    },
    { for k, v in azurerm_management_group.platform_children : k => v.id },
    { for k, v in azurerm_management_group.landing_zone_children : k => v.id },
  )
}

resource "azurerm_management_group_subscription_association" "this" {
  for_each = var.subscription_placements

  management_group_id = local.all_groups[each.value]
  subscription_id     = "/subscriptions/${each.key}"
}
