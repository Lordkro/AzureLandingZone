variable "name" {
  type = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.name))
    error_message = "Storage account names must be 3-24 lowercase alphanumeric characters."
  }
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "replication_type" {
  description = <<-EOT
    Replication for the platform storage account. GZRS is the default: zone
    redundancy in the primary region plus an asynchronous geo copy, which is what
    most compliance baselines expect of platform data. GZRS is not offered in
    every region — fall back to ZRS (zone only) or GRS (geo only) where it is
    unavailable, and accept the narrower guarantee.
  EOT
  type        = string
  default     = "GZRS"

  validation {
    condition     = contains(["GZRS", "RAGZRS", "GRS", "RAGRS", "ZRS", "LRS"], var.replication_type)
    error_message = "replication_type must be one of GZRS, RAGZRS, GRS, RAGRS, ZRS, LRS."
  }
}

variable "private_endpoint_subnet_id" {
  type = string
}

variable "private_dns_zone_id" {
  description = "ID of the privatelink.blob.core.windows.net zone."
  type        = string
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
