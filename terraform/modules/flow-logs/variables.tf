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
  description = "Days to retain raw flow log blobs."
  type        = number
  default     = 30
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
