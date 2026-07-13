locals {
  subscription_scope = "/subscriptions/${var.subscription_id}"

  # Built-in policy definition IDs
  builtin = {
    allowed_locations      = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"
    require_tag_on_rg      = "/providers/Microsoft.Authorization/policyDefinitions/96670d01-0a4d-4649-9c89-2d3abc0a5025"
    inherit_tag_from_rg    = "/providers/Microsoft.Authorization/policyDefinitions/cd3aa116-8754-49c9-a813-ad46512ece54"
    storage_https_only     = "/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9"
    audit_unmanaged_disks  = "/providers/Microsoft.Authorization/policyDefinitions/06a78e20-9358-41c9-923c-fb736d382a4d"
    kv_purge_protection    = "/providers/Microsoft.Authorization/policyDefinitions/0b60c0b2-2dc2-4e1c-b5c9-abbed971de53"
    periodic_update_checks = "/providers/Microsoft.Authorization/policyDefinitions/59efceea-0c96-497e-a4a1-4eb2290dac15"
  }
}

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

resource "azurerm_subscription_policy_assignment" "storage_https_only" {
  name                 = "storage-https-only"
  display_name         = "Secure transfer to storage accounts should be enabled"
  policy_definition_id = local.builtin.storage_https_only
  subscription_id      = local.subscription_scope
}

resource "azurerm_subscription_policy_assignment" "audit_unmanaged_disks" {
  name                 = "audit-unmanaged-disks"
  display_name         = "Audit VMs that do not use managed disks"
  policy_definition_id = local.builtin.audit_unmanaged_disks
  subscription_id      = local.subscription_scope
}

resource "azurerm_subscription_policy_assignment" "kv_purge_protection" {
  name                 = "kv-purge-protection"
  display_name         = "Key vaults should have purge protection enabled"
  policy_definition_id = local.builtin.kv_purge_protection
  subscription_id      = local.subscription_scope
}

# Update Manager: enable periodic assessment on all VMs (modify effect).
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
