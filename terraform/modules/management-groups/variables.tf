variable "prefix" {
  description = "Prefix for management group names (mg-<prefix>, mg-<prefix>-platform, ...)."
  type        = string
}

variable "display_name" {
  description = "Display name of the intermediate root management group."
  type        = string
}

variable "parent_management_group_id" {
  description = <<-EOT
    Full resource ID of the parent management group for the intermediate root.
    Defaults to the Tenant Root Group when null. Set this to nest the hierarchy
    under an existing group instead.
  EOT
  type        = string
  default     = null
}

variable "subscription_placements" {
  description = <<-EOT
    Map of subscription GUID => management group key. Valid keys:
    intermediate_root, platform, identity, management, connectivity,
    landingzones, corp, online, sandbox, decommissioned.

    Example:
      { "00000000-0000-0000-0000-000000000000" = "connectivity" }
  EOT
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for target in values(var.subscription_placements) : contains([
        "intermediate_root", "platform", "identity", "management", "connectivity",
        "landingzones", "corp", "online", "sandbox", "decommissioned",
      ], target)
    ])
    error_message = "Each placement target must be one of: intermediate_root, platform, identity, management, connectivity, landingzones, corp, online, sandbox, decommissioned."
  }
}
