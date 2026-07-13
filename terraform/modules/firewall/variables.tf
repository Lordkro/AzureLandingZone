variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "sku_tier" {
  type    = string
  default = "Standard"
}

variable "subnet_id" {
  description = "ID of the AzureFirewallSubnet."
  type        = string
}

variable "spoke_address_space" {
  description = "Source ranges permitted through the platform rule collections."
  type        = list(string)
}

variable "zones" {
  type    = list(string)
  default = ["1", "2", "3"]
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
