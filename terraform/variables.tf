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
  ]
}

# ---------------------------------------------------------------------------
# Management & security
# ---------------------------------------------------------------------------

variable "log_retention_days" {
  description = "Log Analytics workspace retention in days."
  type        = number
  default     = 90
}

variable "security_contact_email" {
  description = "Email address for Microsoft Defender for Cloud alerts."
  type        = string
  default     = "security@example.com"
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

# ---------------------------------------------------------------------------
# RBAC
# ---------------------------------------------------------------------------

variable "rbac_assignments" {
  description = <<-EOT
    Role assignments keyed by a stable name. Scope defaults to the subscription
    when null. Example:
      platform_ops = {
        principal_id         = "<AAD group object id>"
        role_definition_name = "Contributor"
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
  description = "AAD object IDs granted Key Vault Administrator on the platform vault."
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
