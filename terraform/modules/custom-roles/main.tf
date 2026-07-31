# ---------------------------------------------------------------------------
# Custom role definitions for platform separation of duties.
#
# The built-in Owner/Contributor pair is too coarse for a landing zone: network
# and security teams need write access to their own resource providers without
# the ability to grant themselves more, and workload teams must not be able to
# rewrite platform routing. These roles are modelled on the CAF enterprise-scale
# reference set — treat them as a starting point and tighten per organisation.
#
# Scope note: definitions are created at var.scope and assignable within
# var.assignable_scopes. Point both at a management group once the hierarchy
# exists so a single definition serves every subscription underneath.
# ---------------------------------------------------------------------------

locals {
  default_roles = {
    platform_owner = {
      role_name        = "Azure Platform Owner"
      description      = "Full management of the platform hierarchy, including policy and role assignments. Intended for PIM-eligible platform leads only."
      actions          = ["*"]
      not_actions      = []
      data_actions     = []
      not_data_actions = []
    }

    network_management = {
      role_name   = "Network Management (NetOps)"
      description = "Manage all networking resources — hub, spokes, firewall policy, routing, DNS — without access to other resource providers."
      actions = [
        "*/read",
        "Microsoft.Network/*",
        "Microsoft.Resources/deployments/*",
        "Microsoft.Resources/subscriptions/resourceGroups/read",
        "Microsoft.Insights/alertRules/*",
        "Microsoft.Insights/diagnosticSettings/*",
        "Microsoft.Support/*",
      ]
      not_actions      = []
      data_actions     = []
      not_data_actions = []
    }

    security_operations = {
      role_name   = "Security Operations (SecOps)"
      description = "Manage Defender for Cloud, Sentinel, diagnostics and alerting across the estate. Read-only on everything else."
      actions = [
        "*/read",
        "Microsoft.AlertsManagement/alerts/*",
        "Microsoft.AlertsManagement/alertsSummary/*",
        "Microsoft.Insights/alertRules/*",
        "Microsoft.Insights/diagnosticSettings/*",
        "Microsoft.Insights/eventtypes/*",
        "Microsoft.Insights/scheduledQueryRules/*",
        "Microsoft.OperationalInsights/*",
        "Microsoft.Resources/deployments/*",
        "Microsoft.Security/*",
        "Microsoft.SecurityInsights/*",
        "Microsoft.Support/*",
      ]
      not_actions      = []
      data_actions     = []
      not_data_actions = []
    }

    subscription_owner = {
      role_name   = "Subscription Owner"
      description = "Owner of a landing zone subscription, minus the ability to change platform connectivity or grant roles."
      actions     = ["*"]
      not_actions = [
        "Microsoft.Authorization/*/write",
        "Microsoft.Network/vpnGateways/*",
        "Microsoft.Network/expressRouteCircuits/*",
        "Microsoft.Network/routeTables/write",
        "Microsoft.Network/vpnSites/*",
        "Microsoft.Network/virtualNetworks/peer/action",
      ]
      data_actions     = []
      not_data_actions = []
    }

    application_owner = {
      role_name   = "Application Owner (DevOps)"
      description = "Deploy and operate workloads inside a landing zone. Cannot change networking, policy or role assignments."
      actions = [
        "*/read",
        "Microsoft.AlertsManagement/*",
        "Microsoft.Authorization/locks/*",
        "Microsoft.Insights/*",
        "Microsoft.OperationalInsights/workspaces/*",
        "Microsoft.Resources/deployments/*",
        "Microsoft.Resources/tags/*",
        "Microsoft.Support/*",
        "Microsoft.Compute/*",
        "Microsoft.Web/*",
        "Microsoft.ContainerService/*",
        "Microsoft.KeyVault/vaults/read",
        "Microsoft.Storage/storageAccounts/*",
      ]
      not_actions = [
        "Microsoft.Authorization/roleAssignments/write",
        "Microsoft.Authorization/roleDefinitions/write",
        "Microsoft.Authorization/policyAssignments/write",
        "Microsoft.Network/routeTables/write",
        "Microsoft.Network/virtualNetworks/write",
        "Microsoft.Network/virtualNetworks/peer/action",
      ]
      data_actions     = []
      not_data_actions = []
    }
  }

  roles = merge(
    { for k, v in local.default_roles : k => v if contains(var.enabled_roles, k) },
    var.additional_roles,
  )
}

resource "azurerm_role_definition" "this" {
  for_each = local.roles

  # Deterministic GUID so re-running Terraform never recreates the definition
  # (which would orphan every assignment that references it).
  role_definition_id = uuidv5("url", "${var.scope}/${each.value.role_name}")

  name        = each.value.role_name
  scope       = var.scope
  description = each.value.description

  permissions {
    actions          = each.value.actions
    not_actions      = each.value.not_actions
    data_actions     = each.value.data_actions
    not_data_actions = each.value.not_data_actions
  }

  assignable_scopes = coalescelist(var.assignable_scopes, [var.scope])
}
