variable "zones" {
  description = "Private DNS zone names to create."
  type        = list(string)
}

variable "resource_group_name" {
  type = string
}

variable "virtual_network_ids" {
  description = "Map of friendly name => VNet resource ID to link each zone to."
  type        = map(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
