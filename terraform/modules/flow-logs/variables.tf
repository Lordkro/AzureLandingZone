variable "resource_group_name" {
  description = "Resource group for the flow log storage account."
  type        = string
}

variable "location" {
  type = string
}

variable "storage_account_name" {
  description = "Globally unique name for the flow log storage account."
  type        = string
}

variable "storage_allowed_ip_rules" {
  description = "Public IPs allowed to read flow log blobs directly (e.g. an analyst workstation egress IP)."
  type        = list(string)
  default     = []
}

variable "storage_replication_type" {
  description = "Replication for the flow log account. ZRS keeps the evidence available through a zone outage."
  type        = string
  default     = "ZRS"

  validation {
    condition     = contains(["ZRS", "GRS", "GZRS", "RAGRS", "LRS"], var.storage_replication_type)
    error_message = "storage_replication_type must be one of ZRS, GRS, GZRS, RAGRS, LRS."
  }
}

variable "sas_expiration_period" {
  description = "Maximum lifetime of a SAS token issued against the flow log account, as DD.HH:MM:SS."
  type        = string
  default     = "07.00:00:00"
}

variable "virtual_network_ids" {
  description = "Map of short name => virtual network resource ID to enable flow logs on."
  type        = map(string)
}

variable "network_watcher_name" {
  description = "Name of the regional Network Watcher (usually NetworkWatcher_<region>)."
  type        = string
}

variable "network_watcher_resource_group_name" {
  description = "Resource group holding the Network Watcher (usually NetworkWatcherRG)."
  type        = string
  default     = "NetworkWatcherRG"
}

variable "retention_days" {
  description = <<-EOT
    Days to retain raw flow log blobs. 90 is the floor most compliance baselines
    expect for network logs (and what Checkov's CKV_AZURE_12 enforces); lower it
    only in non-prod, where cost matters more than evidence.
  EOT
  type        = number
  default     = 90

  validation {
    condition     = var.retention_days >= 1 && var.retention_days <= 365
    error_message = "retention_days must be between 1 and 365."
  }
}

variable "traffic_analytics_enabled" {
  description = "Process flow logs into the workspace. Adds ingestion cost but is what makes the data usable."
  type        = bool
  default     = true
}

variable "traffic_analytics_interval_in_minutes" {
  description = "Traffic Analytics processing interval — 10 or 60."
  type        = number
  default     = 60

  validation {
    condition     = contains([10, 60], var.traffic_analytics_interval_in_minutes)
    error_message = "Traffic Analytics interval must be 10 or 60 minutes."
  }
}

variable "log_analytics_workspace_id" {
  description = "Resource ID of the workspace."
  type        = string
}

variable "log_analytics_workspace_customer_id" {
  description = "Workspace (customer) GUID."
  type        = string
}

variable "log_analytics_workspace_location" {
  description = "Region of the workspace."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
