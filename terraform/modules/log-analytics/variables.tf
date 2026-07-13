variable "name" {
  description = "Workspace name."
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "retention_in_days" {
  type    = number
  default = 90
}

variable "daily_quota_gb" {
  description = "Daily ingestion cap in GB. -1 = unlimited."
  type        = number
  default     = -1
}

variable "tags" {
  type    = map(string)
  default = {}
}
