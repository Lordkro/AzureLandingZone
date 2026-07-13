variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "address_space" {
  type = list(string)
}

variable "workload_subnet_prefix" {
  type = string
}

variable "app_gateway_subnet_prefix" {
  type = string
}

variable "private_endpoints_prefix" {
  type = string
}

variable "hub_vnet_id" {
  type = string
}

variable "hub_vnet_name" {
  type = string
}

variable "hub_resource_group_name" {
  type = string
}

variable "firewall_private_ip" {
  type = string
}

variable "use_remote_gateways" {
  description = "Route on-prem traffic through the hub VPN gateway."
  type        = bool
  default     = true
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
