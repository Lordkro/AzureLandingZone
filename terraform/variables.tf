variable "subscription_id" {
  description = <<-EOT
    Target subscription ID. Leave null in CI (ARM_SUBSCRIPTION_ID is supplied by
    the workflow); set it for local runs against a non-default subscription.
  EOT
  type        = string
  default     = null
}

variable "prefix" {
  description = "Organisation / workload prefix used in resource names (lowercase alphanumeric)."
  type        = string
  default     = "alz"

  validation {
    condition     = can(regex("^[a-z0-9]{2,8}$", var.prefix))
    error_message = "Prefix must be 2-8 lowercase alphanumeric characters."
  }
}

variable "environment" {
  description = "Environment name (prod, dev, test, ...)."
  type        = string
  default     = "prod"
}

variable "location" {
  description = "Primary Azure region."
  type        = string
  default     = "westeurope"
}

variable "location_short" {
  description = "Short code for the region, used in resource names (e.g. weu, san)."
  type        = string
  default     = "weu"
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default = {
    workload   = "landing-zone"
    managed_by = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Management groups
# ---------------------------------------------------------------------------

variable "enable_management_groups" {
  description = <<-EOT
    Create the CAF management group hierarchy (Platform / Landing Zones /
    Sandbox / Decommissioned). Requires Owner or Management Group Contributor on
    the Tenant Root Group — off by default because most subscription-scoped
    deployment identities cannot do this.
  EOT
  type        = bool
  default     = false
}

variable "management_group_display_name" {
  description = "Display name of the intermediate root management group."
  type        = string
  default     = "Landing Zone"
}

variable "parent_management_group_id" {
  description = "Parent for the intermediate root. Null anchors it at the Tenant Root Group."
  type        = string
  default     = null
}

variable "management_group_subscription_placements" {
  description = "Map of subscription GUID => hierarchy key (e.g. corp, online, connectivity, sandbox)."
  type        = map(string)
  default     = {}
}

variable "management_group_placement_for_this_subscription" {
  description = <<-EOT
    Hierarchy key the subscription being deployed into should be moved to
    (e.g. "connectivity" for a platform subscription, "corp" for a workload
    landing zone). Null leaves the subscription where it is.
  EOT
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

variable "hub_address_space" {
  description = "Address space of the hub virtual network."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "hub_subnets" {
  description = "Hub subnet address prefixes."
  type = object({
    firewall        = string
    gateway         = string
    bastion         = string
    shared_services = string
  })
  default = {
    firewall        = "10.0.1.0/26"
    gateway         = "10.0.2.0/27"
    bastion         = "10.0.3.0/26"
    shared_services = "10.0.4.0/24"
  }
}

variable "spoke_address_space" {
  description = "Address space of the workload spoke virtual network."
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

variable "spoke_subnets" {
  description = "Spoke subnet address prefixes."
  type = object({
    workload          = string
    app_gateway       = string
    private_endpoints = string
  })
  default = {
    workload          = "10.1.1.0/24"
    app_gateway       = "10.1.2.0/24"
    private_endpoints = "10.1.3.0/24"
  }
}

variable "firewall_sku_tier" {
  description = "Azure Firewall SKU tier (Standard or Premium)."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.firewall_sku_tier)
    error_message = "Firewall SKU tier must be Standard or Premium."
  }
}

variable "enable_ddos_protection" {
  description = <<-EOT
    Create a DDoS Network Protection plan and attach hub + spoke to it. This is
    a flat ~USD 3k/month charge covering up to 100 public IPs across the tenant,
    so enable it once per tenant, not once per landing zone.
  EOT
  type        = bool
  default     = false
}

variable "vpn_gateway_sku" {
  description = "VPN Gateway SKU (zone-redundant AZ SKUs recommended for production)."
  type        = string
  default     = "VpnGw1AZ"
}

variable "vpn_client_address_space" {
  description = "Point-to-site VPN client address pool. Empty list disables P2S."
  type        = list(string)
  default     = []
}

variable "onprem_gateways" {
  description = "Site-to-site connections to on-premises VPN devices, keyed by connection name."
  type = map(object({
    gateway_address = string
    address_space   = list(string)
  }))
  default = {}
}

variable "onprem_shared_keys" {
  description = "IPsec pre-shared keys, keyed by the same names as onprem_gateways. Supply via TF_VAR_onprem_shared_keys or a secret store, not tfvars."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "private_dns_zones" {
  description = "Private DNS zones to create and link to hub and spoke."
  type        = list(string)
  default = [
    "privatelink.vaultcore.azure.net",
    "privatelink.blob.core.windows.net",
    "privatelink.file.core.windows.net",
    "privatelink.queue.core.windows.net",
    "privatelink.table.core.windows.net",
    "privatelink.database.windows.net",
    "privatelink.azurewebsites.net",
    "privatelink.azurecr.io",
    # Azure Monitor private link set — required for Azure Monitor Agent
    # ingestion and Log Analytics queries once egress is locked down. These four
    # plus the blob zone above form the complete set; a partial set silently
    # breaks agent ingestion.
    "privatelink.monitor.azure.com",
    "privatelink.oms.opinsights.azure.com",
    "privatelink.ods.opinsights.azure.com",
    "privatelink.agentsvc.azure-automation.net",
  ]

  validation {
    condition     = length(var.private_dns_zones) == length(distinct(var.private_dns_zones))
    error_message = "private_dns_zones must not contain duplicates."
  }
}

# ---------------------------------------------------------------------------
# Flow logs
# ---------------------------------------------------------------------------

variable "enable_flow_logs" {
  description = <<-EOT
    Enable VNet flow logs with Traffic Analytics on hub and spoke. Requires a
    Network Watcher in the region (Azure normally auto-creates
    NetworkWatcher_<region> in NetworkWatcherRG) and adds storage plus workspace
    ingestion cost.
  EOT
  type        = bool
  default     = false
}

variable "network_watcher_name" {
  description = "Network Watcher name. Null derives NetworkWatcher_<location>."
  type        = string
  default     = null
}

variable "network_watcher_resource_group_name" {
  description = "Resource group holding the Network Watcher."
  type        = string
  default     = "NetworkWatcherRG"
}

variable "flow_log_retention_days" {
  description = "Days to retain raw flow log blobs."
  type        = number
  default     = 30
}

# ---------------------------------------------------------------------------
# Management & security
# ---------------------------------------------------------------------------

variable "log_retention_days" {
  description = "Log Analytics workspace retention in days."
  type        = number
  default     = 90
}

variable "log_daily_quota_gb" {
  description = "Daily ingestion cap in GB for the workspace. -1 = unlimited (production default); cap it in non-prod."
  type        = number
  default     = -1
}

variable "security_contact_email" {
  description = "Email address for Microsoft Defender for Cloud alerts."
  type        = string
  default     = "security@example.com"
}

variable "platform_alert_emails" {
  description = "Additional email addresses added to the platform action group (service health, resource health, firewall and gateway alerts)."
  type        = list(string)
  default     = []
}

variable "platform_alert_webhooks" {
  description = "Webhook URIs (Teams, PagerDuty, ...) added to the platform action group."
  type        = list(string)
  default     = []
}

variable "defender_plans" {
  description = "Microsoft Defender for Cloud plans to enable."
  type        = list(string)
  default = [
    "VirtualMachines",
    "StorageAccounts",
    "KeyVaults",
    "Arm",
    "Containers",
    "AppServices",
    "SqlServers",
  ]
}

variable "enable_resource_locks" {
  description = "Apply CanNotDelete locks to the hub, management and security resource groups."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Policy
# ---------------------------------------------------------------------------

variable "allowed_locations" {
  description = "Regions permitted by the allowed-locations policy assignment."
  type        = list(string)
  default     = ["westeurope", "northeurope"]
}

variable "required_tags" {
  description = "Tag names that policy requires on resource groups."
  type        = list(string)
  default     = ["workload", "environment"]
}

variable "denied_resource_types" {
  description = "Resource types blocked outright, e.g. [\"Microsoft.ClassicCompute/virtualMachines\"]. Empty list skips the assignment."
  type        = list(string)
  default     = []
}

variable "deny_public_ip_on_nic" {
  description = "Deny public IPs on network interfaces — they bypass the hub firewall and the forced-tunnelling route table."
  type        = bool
  default     = true
}

variable "storage_public_access_effect" {
  description = "Effect for the 'Storage accounts should disable public network access' assignment. Start at Audit, move to Deny once workloads comply."
  type        = string
  default     = "Audit"
}

variable "deploy_azure_monitor_agent" {
  description = "Assign policies that install Azure Monitor Agent on VMs and bind them to the platform data collection rule."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Patching
# ---------------------------------------------------------------------------

variable "maintenance_window" {
  description = "Update Manager maintenance window (UTC)."
  type = object({
    start_date_time = string # "2026-08-01 02:00"
    duration        = string # "03:55"
    recur_every     = string # "1Week Sunday"
  })
  default = {
    start_date_time = "2026-08-01 02:00"
    duration        = "03:55"
    recur_every     = "1Week Sunday"
  }
}

variable "patch_tag" {
  description = "Tag that enrols a VM into the maintenance window."
  type = object({
    name  = string
    value = string
  })
  default = {
    name  = "patch-schedule"
    value = "default"
  }
}

# ---------------------------------------------------------------------------
# Cost management
# ---------------------------------------------------------------------------

variable "monthly_budget_amount" {
  description = "Monthly budget in the billing currency. Null disables the budget and its alerts."
  type        = number
  default     = null
}

variable "budget_start_date" {
  description = "Budget start — first of a month, RFC3339."
  type        = string
  default     = "2026-08-01T00:00:00Z"
}

variable "budget_end_date" {
  description = "Budget end, RFC3339."
  type        = string
  default     = "2030-08-01T00:00:00Z"
}

# ---------------------------------------------------------------------------
# RBAC
# ---------------------------------------------------------------------------

variable "enable_custom_roles" {
  description = <<-EOT
    Create the platform custom role definitions (Azure Platform Owner, Network
    Management, Security Operations, Subscription Owner, Application Owner).
    Requires User Access Administrator or Owner.
  EOT
  type        = bool
  default     = true
}

variable "rbac_assignments" {
  description = <<-EOT
    Role assignments keyed by a stable name. Scope defaults to the subscription
    when null. role_definition_name accepts built-in names or the display name
    of a custom role created by the custom-roles module. Example:
      platform_ops = {
        principal_id         = "<Entra group object id>"
        role_definition_name = "Network Management (NetOps)"
        scope                = null
      }
  EOT
  type = map(object({
    principal_id         = string
    role_definition_name = string
    scope                = optional(string)
  }))
  default = {}
}

# ---------------------------------------------------------------------------
# Workload services
# ---------------------------------------------------------------------------

variable "key_vault_admin_object_ids" {
  description = "Entra object IDs granted Key Vault Administrator on the platform vault."
  type        = list(string)
  default     = []
}

variable "app_gateway_capacity" {
  description = "Autoscale bounds for Application Gateway."
  type = object({
    min = number
    max = number
  })
  default = {
    min = 1
    max = 3
  }
}
