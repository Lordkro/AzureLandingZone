variable "subscription_id" {
  type = string
}

variable "location" {
  description = "Region for policy assignments with managed identities."
  type        = string
}

variable "allowed_locations" {
  type = list(string)
}

variable "required_tags" {
  type = list(string)
}

variable "denied_resource_types" {
  description = <<-EOT
    Resource types blocked by the 'Not allowed resource types' policy, e.g.
    ["Microsoft.ClassicCompute/virtualMachines"]. No assignment is created when
    this list is empty.
  EOT
  type        = list(string)
  default     = []
}

variable "deny_public_ip_on_nic" {
  description = "Deny public IPs on network interfaces. Public IPs bypass the hub firewall and forced-tunnelling routes."
  type        = bool
  default     = true
}

variable "storage_public_access_effect" {
  description = "Effect for the 'Storage accounts should disable public network access' assignment (Audit or Deny)."
  type        = string
  default     = "Audit"

  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.storage_public_access_effect)
    error_message = "Effect must be Audit, Deny or Disabled."
  }
}

variable "deploy_azure_monitor_agent" {
  description = "Assign the policies that install Azure Monitor Agent on VMs and bind them to the platform data collection rule."
  type        = bool
  default     = true
}

variable "data_collection_rule_id" {
  description = "Resource ID of the platform data collection rule. Required for the DCR association policies; null skips them."
  type        = string
  default     = null
}
