variable "subscription_id" {
  type = string
}

variable "assignments" {
  description = "Role assignments keyed by stable name. Scope defaults to subscription."
  type = map(object({
    principal_id         = string
    role_definition_name = string
    scope                = optional(string)
  }))
  default = {}
}
