output "assignment_ids" {
  value = concat(
    [
      azurerm_subscription_policy_assignment.allowed_locations.id,
      azurerm_subscription_policy_assignment.storage_https_only.id,
      azurerm_subscription_policy_assignment.audit_unmanaged_disks.id,
      azurerm_subscription_policy_assignment.kv_purge_protection.id,
      azurerm_subscription_policy_assignment.periodic_update_checks.id,
    ],
    [for a in azurerm_subscription_policy_assignment.require_tags : a.id],
    [for a in azurerm_subscription_policy_assignment.inherit_tags : a.id],
  )
}
