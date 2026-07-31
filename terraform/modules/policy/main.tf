locals {
  subscription_scope = "/subscriptions/${var.subscription_id}"

  # Built-in policy definition IDs. Verify with:
  #   az policy definition show --name <guid> --query displayName
  builtin = {
    allowed_locations       = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"
    require_tag_on_rg       = "/providers/Microsoft.Authorization/policyDefinitions/96670d01-0a4d-4649-9c89-2d3abc0a5025"
    inherit_tag_from_rg     = "/providers/Microsoft.Authorization/policyDefinitions/cd3aa116-8754-49c9-a813-ad46512ece54"
    storage_https_only      = "/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9"
    audit_unmanaged_disks   = "/providers/Microsoft.Authorization/policyDefinitions/06a78e20-9358-41c9-923c-fb736d382a4d"
    kv_purge_protection     = "/providers/Microsoft.Authorization/policyDefinitions/0b60c0b2-2dc2-4e1c-b5c9-abbed971de53"
    periodic_update_checks  = "/providers/Microsoft.Authorization/policyDefinitions/59efceea-0c96-497e-a4a1-4eb2290dac15"
    nic_no_public_ip        = "/providers/Microsoft.Authorization/policyDefinitions/83a86a26-fd1f-447c-b59d-e51f44264114"
    storage_no_public_net   = "/providers/Microsoft.Authorization/policyDefinitions/b2982f36-99f2-4db5-8eff-283140c09693"
    kv_firewall_enabled     = "/providers/Microsoft.Authorization/policyDefinitions/55615ac9-af46-4a59-874e-391cc3dfb490"
    security_contact_email  = "/providers/Microsoft.Authorization/policyDefinitions/4f4f78b8-e367-4b10-a341-d9a4ad5cf1c7"
    not_allowed_types       = "/providers/Microsoft.Authorization/policyDefinitions/6c112d4e-5bc7-47ae-a041-ea2d9dccd749"
    ama_windows_vm          = "/providers/Microsoft.Authorization/policyDefinitions/ca817e41-e85a-4783-bc7f-dc532d36235e"
    ama_linux_vm            = "/providers/Microsoft.Authorization/policyDefinitions/a4034bc6-ae50-406d-bf76-50f4ee5a7811"
    dcr_association_windows = "/providers/Microsoft.Authorization/policyDefinitions/244efd75-0d92-453c-b9a3-7d73ca36ed52"
    dcr_association_linux   = "/providers/Microsoft.Authorization/policyDefinitions/58e891b9-ce13-4ac3-86e4-ac3e1f20cb07"
  }
}

# ---------------------------------------------------------------------------
# Governance: locations and tagging
# ---------------------------------------------------------------------------

resource "azurerm_subscription_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations"
  display_name         = "Allowed locations"
  policy_definition_id = local.builtin.allowed_locations
  subscription_id      = local.subscription_scope

  parameters = jsonencode({
    listOfAllowedLocations = { value = var.allowed_locations }
  })
}

resource "azurerm_subscription_policy_assignment" "require_tags" {
  for_each = toset(var.required_tags)

  name                 = "require-tag-${each.value}"
  display_name         = "Require '${each.value}' tag on resource groups"
  policy_definition_id = local.builtin.require_tag_on_rg
  subscription_id      = local.subscription_scope

  parameters = jsonencode({
    tagName = { value = each.value }
  })
}

resource "azurerm_subscription_policy_assignment" "inherit_tags" {
  for_each = toset(var.required_tags)

  name                 = "inherit-tag-${each.value}"
  display_name         = "Inherit '${each.value}' tag from resource group"
  policy_definition_id = local.builtin.inherit_tag_from_rg
  subscription_id      = local.subscription_scope
  location             = var.location

  identity {
    type = "SystemAssigned"
  }

  parameters = jsonencode({
    tagName = { value = each.value }
  })
}

# Modify-effect assignments need Contributor to remediate.
resource "azurerm_role_assignment" "inherit_tags_remediation" {
  for_each = toset(var.required_tags)

  scope                = local.subscription_scope
  role_definition_name = "Contributor"
  principal_id         = azurerm_subscription_policy_assignment.inherit_tags[each.value].identity[0].principal_id
}

# Blocks whole resource providers or SKUs the organisation has not approved
# (e.g. Microsoft.ClassicCompute). Skipped when the list is empty.
resource "azurerm_subscription_policy_assignment" "not_allowed_resource_types" {
  count = length(var.denied_resource_types) > 0 ? 1 : 0

  name                 = "not-allowed-resource-types"
  display_name         = "Not allowed resource types"
  policy_definition_id = local.builtin.not_allowed_types
  subscription_id      = local.subscription_scope

  parameters = jsonencode({
    listOfResourceTypesNotAllowed = { value = var.denied_resource_types }
    effect                        = { value = "Deny" }
  })
}

# ---------------------------------------------------------------------------
# Data protection
# ---------------------------------------------------------------------------

resource "azurerm_subscription_policy_assignment" "storage_https_only" {
  name                 = "storage-https-only"
  display_name         = "Secure transfer to storage accounts should be enabled"
  policy_definition_id = local.builtin.storage_https_only
  subscription_id      = local.subscription_scope

  parameters = jsonencode({
    effect = { value = "Deny" }
  })
}

# The landing zone's own storage disables public network access; this stops
# workload teams from creating accounts that do not.
resource "azurerm_subscription_policy_assignment" "storage_no_public_network" {
  name                 = "storage-no-public-network"
  display_name         = "Storage accounts should disable public network access"
  policy_definition_id = local.builtin.storage_no_public_net
  subscription_id      = local.subscription_scope

  parameters = jsonencode({
    effect = { value = var.storage_public_access_effect }
  })
}

resource "azurerm_subscription_policy_assignment" "kv_purge_protection" {
  name                 = "kv-purge-protection"
  display_name         = "Key vaults should have purge protection enabled"
  policy_definition_id = local.builtin.kv_purge_protection
  subscription_id      = local.subscription_scope

  parameters = jsonencode({
    effect = { value = "Audit" }
  })
}

resource "azurerm_subscription_policy_assignment" "kv_firewall_enabled" {
  name                 = "kv-firewall-enabled"
  display_name         = "Key vaults should have firewall enabled or public network access disabled"
  policy_definition_id = local.builtin.kv_firewall_enabled
  subscription_id      = local.subscription_scope

  parameters = jsonencode({
    effect = { value = "Audit" }
  })
}

resource "azurerm_subscription_policy_assignment" "audit_unmanaged_disks" {
  name                 = "audit-unmanaged-disks"
  display_name         = "Audit VMs that do not use managed disks"
  policy_definition_id = local.builtin.audit_unmanaged_disks
  subscription_id      = local.subscription_scope
}

# ---------------------------------------------------------------------------
# Network isolation
# ---------------------------------------------------------------------------

# Every route out of the spoke goes through the firewall. A public IP on a NIC
# bypasses that path entirely, so deny it outright rather than audit it.
resource "azurerm_subscription_policy_assignment" "nic_no_public_ip" {
  count = var.deny_public_ip_on_nic ? 1 : 0

  name                 = "nic-no-public-ip"
  display_name         = "Network interfaces should not have public IPs"
  description          = "Public IPs on NICs bypass the hub firewall and the forced-tunnelling route table."
  policy_definition_id = local.builtin.nic_no_public_ip
  subscription_id      = local.subscription_scope
}

# ---------------------------------------------------------------------------
# Security posture
# ---------------------------------------------------------------------------

resource "azurerm_subscription_policy_assignment" "security_contact_email" {
  name                 = "security-contact-email"
  display_name         = "Subscriptions should have a contact email address for security issues"
  policy_definition_id = local.builtin.security_contact_email
  subscription_id      = local.subscription_scope
}

# ---------------------------------------------------------------------------
# Update Manager: enable periodic assessment on all VMs (modify effect).
# ---------------------------------------------------------------------------

resource "azurerm_subscription_policy_assignment" "periodic_update_checks" {
  name                 = "periodic-update-checks"
  display_name         = "Configure periodic checking for missing system updates"
  policy_definition_id = local.builtin.periodic_update_checks
  subscription_id      = local.subscription_scope
  location             = var.location

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "periodic_update_checks_remediation" {
  scope                = local.subscription_scope
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_subscription_policy_assignment.periodic_update_checks.identity[0].principal_id
}

# ---------------------------------------------------------------------------
# Azure Monitor Agent: install it, then bind it to the platform DCR.
#
# Without these two pairs the data collection rule created by the log-analytics
# module collects nothing — VMs would need the agent installed and associated by
# hand. This is what turns the DCR into an actual monitoring baseline.
# ---------------------------------------------------------------------------

locals {
  ama_assignments = var.deploy_azure_monitor_agent ? {
    ama-windows = {
      display_name  = "Configure Windows virtual machines to run Azure Monitor Agent"
      definition_id = local.builtin.ama_windows_vm
      parameters    = {}
    }
    ama-linux = {
      display_name  = "Configure Linux virtual machines to run Azure Monitor Agent"
      definition_id = local.builtin.ama_linux_vm
      parameters    = {}
    }
  } : {}

  dcr_assignments = var.deploy_azure_monitor_agent && var.data_collection_rule_id != null ? {
    dcr-windows = {
      display_name  = "Associate Windows VMs with the platform data collection rule"
      definition_id = local.builtin.dcr_association_windows
    }
    dcr-linux = {
      display_name  = "Associate Linux VMs with the platform data collection rule"
      definition_id = local.builtin.dcr_association_linux
    }
  } : {}
}

resource "azurerm_subscription_policy_assignment" "ama" {
  for_each = local.ama_assignments

  name                 = each.key
  display_name         = each.value.display_name
  policy_definition_id = each.value.definition_id
  subscription_id      = local.subscription_scope
  location             = var.location

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "ama_remediation" {
  for_each = local.ama_assignments

  scope                = local.subscription_scope
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_subscription_policy_assignment.ama[each.key].identity[0].principal_id
}

resource "azurerm_subscription_policy_assignment" "dcr_association" {
  for_each = local.dcr_assignments

  name                 = each.key
  display_name         = each.value.display_name
  policy_definition_id = each.value.definition_id
  subscription_id      = local.subscription_scope
  location             = var.location

  identity {
    type = "SystemAssigned"
  }

  parameters = jsonencode({
    dcrResourceId = { value = var.data_collection_rule_id }
    resourceType  = { value = "Microsoft.Insights/dataCollectionRules" }
  })
}

# The DCR association policy needs to read the rule and write the association.
resource "azurerm_role_assignment" "dcr_monitoring_contributor" {
  for_each = local.dcr_assignments

  scope                = local.subscription_scope
  role_definition_name = "Monitoring Contributor"
  principal_id         = azurerm_subscription_policy_assignment.dcr_association[each.key].identity[0].principal_id
}

resource "azurerm_role_assignment" "dcr_log_analytics_contributor" {
  for_each = local.dcr_assignments

  scope                = local.subscription_scope
  role_definition_name = "Log Analytics Contributor"
  principal_id         = azurerm_subscription_policy_assignment.dcr_association[each.key].identity[0].principal_id
}
