output "assignment_ids" {
  description = "Resource IDs of every policy assignment created by this module."
  value = concat(
    [
      azurerm_subscription_policy_assignment.allowed_locations.id,
      azurerm_subscription_policy_assignment.storage_https_only.id,
      azurerm_subscription_policy_assignment.storage_no_public_network.id,
      azurerm_subscription_policy_assignment.audit_unmanaged_disks.id,
      azurerm_subscription_policy_assignment.kv_purge_protection.id,
      azurerm_subscription_policy_assignment.kv_firewall_enabled.id,
      azurerm_subscription_policy_assignment.security_contact_email.id,
      azurerm_subscription_policy_assignment.periodic_update_checks.id,
    ],
    [for a in azurerm_subscription_policy_assignment.require_tags : a.id],
    [for a in azurerm_subscription_policy_assignment.inherit_tags : a.id],
    [for a in azurerm_subscription_policy_assignment.not_allowed_resource_types : a.id],
    [for a in azurerm_subscription_policy_assignment.nic_no_public_ip : a.id],
    [for a in azurerm_subscription_policy_assignment.ama : a.id],
    [for a in azurerm_subscription_policy_assignment.dcr_association : a.id],
  )
}

output "remediation_identity_principal_ids" {
  description = "Principal IDs of the policy remediation identities, for auditing what the platform can change."
  value = merge(
    { for k, a in azurerm_subscription_policy_assignment.inherit_tags : "inherit-tag-${k}" => a.identity[0].principal_id },
    { for k, a in azurerm_subscription_policy_assignment.ama : k => a.identity[0].principal_id },
    { for k, a in azurerm_subscription_policy_assignment.dcr_association : k => a.identity[0].principal_id },
    { "periodic-update-checks" = azurerm_subscription_policy_assignment.periodic_update_checks.identity[0].principal_id },
  )
}
