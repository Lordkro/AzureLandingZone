variable "subscription_id" {
  type = string
}

variable "plans" {
  description = "Defender for Cloud resource types to enable at Standard tier."
  type        = list(string)
}

variable "security_contact_email" {
  type = string
}

variable "log_analytics_workspace_id" {
  type = string
}
