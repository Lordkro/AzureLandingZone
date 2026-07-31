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

variable "security_contact_phone" {
  description = "Phone number Defender uses for high-severity escalation, E.164 format."
  type        = string

  validation {
    condition     = can(regex("^\\+[0-9]{7,15}$", var.security_contact_phone))
    error_message = "security_contact_phone must be E.164 format, e.g. +441234567890."
  }
}

variable "log_analytics_workspace_id" {
  type = string
}
