variable "name" {
  type = string
}

variable "subscription_id" {
  type = string
}

variable "amount" {
  description = "Budget amount in the billing account currency."
  type        = number
}

variable "time_grain" {
  description = "Reset period: Monthly, Quarterly or Annually."
  type        = string
  default     = "Monthly"

  validation {
    condition     = contains(["Monthly", "Quarterly", "Annually"], var.time_grain)
    error_message = "time_grain must be Monthly, Quarterly or Annually."
  }
}

variable "start_date" {
  description = "Budget start — must be the first day of a month, RFC3339 (e.g. 2026-08-01T00:00:00Z)."
  type        = string

  validation {
    condition     = can(regex("^\\d{4}-\\d{2}-01T00:00:00Z$", var.start_date))
    error_message = "start_date must be the first of a month at midnight UTC, e.g. 2026-08-01T00:00:00Z."
  }
}

variable "end_date" {
  description = "Budget end, RFC3339."
  type        = string
}

variable "actual_thresholds" {
  description = "Percentages of the budget at which actual-spend alerts fire."
  type        = list(number)
  default     = [80, 100]
}

variable "forecast_thresholds" {
  description = "Percentages of the budget at which forecast alerts fire."
  type        = list(number)
  default     = [100]
}

variable "contact_emails" {
  description = "Email addresses notified directly by Cost Management."
  type        = list(string)
  default     = []
}

variable "action_group_ids" {
  description = "Action group resource IDs notified when a threshold is crossed."
  type        = list(string)
  default     = []
}
