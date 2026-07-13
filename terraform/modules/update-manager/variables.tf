variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "maintenance_window" {
  type = object({
    start_date_time = string
    duration        = string
    recur_every     = string
  })
}

variable "patch_tag_name" {
  description = "VMs carrying this tag are enrolled in the maintenance window."
  type        = string
  default     = "patch-schedule"
}

variable "patch_tag_value" {
  type    = string
  default = "default"
}

variable "tags" {
  type    = map(string)
  default = {}
}
