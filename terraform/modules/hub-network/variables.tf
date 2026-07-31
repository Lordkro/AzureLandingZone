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

variable "firewall_subnet_prefix" {
  type = string
}

variable "gateway_subnet_prefix" {
  type = string
}

variable "bastion_subnet_prefix" {
  type = string
}

variable "shared_services_prefix" {
  type = string
}

variable "ddos_protection_plan_id" {
  description = "DDoS Network Protection plan to attach. Null leaves the VNet on the free Basic tier."
  type        = string
  default     = null
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
