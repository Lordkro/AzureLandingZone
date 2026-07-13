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
  description = "ID of the AzureBastionSubnet (/26 or larger)."
  type        = string
}

variable "scale_units" {
  type    = number
  default = 2
}

variable "zones" {
  type    = list(string)
  default = []
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
