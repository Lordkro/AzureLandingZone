variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "subnet_id" {
  description = "Dedicated Application Gateway subnet ID."
  type        = string
}

variable "autoscale_min" {
  type    = number
  default = 1
}

variable "autoscale_max" {
  type    = number
  default = 3
}

variable "zones" {
  type    = list(string)
  default = ["1", "2", "3"]
}

variable "ssl_policy_name" {
  description = <<-EOT
    Predefined SSL policy. AppGwSslPolicy20220101S is the strict profile: TLS 1.2
    floor, strong cipher suites only. Drop to AppGwSslPolicy20220101 if a client
    genuinely cannot negotiate the reduced cipher set.
  EOT
  type        = string
  default     = "AppGwSslPolicy20220101S"

  validation {
    condition = contains([
      "AppGwSslPolicy20220101S",
      "AppGwSslPolicy20220101",
      "AppGwSslPolicy20170401S",
    ], var.ssl_policy_name)
    error_message = "ssl_policy_name must be AppGwSslPolicy20220101S, AppGwSslPolicy20220101 or AppGwSslPolicy20170401S."
  }
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
