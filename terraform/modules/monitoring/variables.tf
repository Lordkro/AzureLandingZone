variable "subscription_id" {
  type = string
}

variable "suffix" {
  description = "Naming suffix (<prefix>-<environment>-<region>)."
  type        = string
}

variable "short_name_suffix" {
  description = "Short string appended to the action group short name (max 12 chars total)."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group holding the action group and alert rules."
  type        = string
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "notification_emails" {
  description = "Email addresses that receive platform alerts."
  type        = list(string)
  default     = []
}

variable "notification_webhooks" {
  description = "Webhook URIs (Teams, PagerDuty, ...) that receive platform alerts."
  type        = list(string)
  default     = []
}

variable "service_health_locations" {
  description = "Regions to watch for service health events."
  type        = list(string)
}

variable "firewall_id" {
  type = string
}

variable "app_gateway_id" {
  description = "Application Gateway resource ID; null disables its metric alert."
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
