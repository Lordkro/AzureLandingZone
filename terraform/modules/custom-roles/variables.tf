variable "scope" {
  description = "Scope the role definitions are created at — a subscription or management group resource ID."
  type        = string
}

variable "assignable_scopes" {
  description = "Scopes the roles may be assigned at. Defaults to [var.scope] when empty."
  type        = list(string)
  default     = []
}

variable "enabled_roles" {
  description = <<-EOT
    Which of the built-in-to-this-module role definitions to create. Valid keys:
    platform_owner, network_management, security_operations, subscription_owner,
    application_owner.
  EOT
  type        = list(string)
  default = [
    "platform_owner",
    "network_management",
    "security_operations",
    "subscription_owner",
    "application_owner",
  ]

  validation {
    condition = alltrue([
      for r in var.enabled_roles : contains([
        "platform_owner", "network_management", "security_operations",
        "subscription_owner", "application_owner",
      ], r)
    ])
    error_message = "enabled_roles may only contain: platform_owner, network_management, security_operations, subscription_owner, application_owner."
  }
}

variable "additional_roles" {
  description = "Extra custom roles, keyed by a stable name. Merged over the defaults."
  type = map(object({
    role_name        = string
    description      = string
    actions          = list(string)
    not_actions      = optional(list(string), [])
    data_actions     = optional(list(string), [])
    not_data_actions = optional(list(string), [])
  }))
  default = {}
}
