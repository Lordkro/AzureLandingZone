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

variable "log_analytics_workspace_id" {
  type = string
}
