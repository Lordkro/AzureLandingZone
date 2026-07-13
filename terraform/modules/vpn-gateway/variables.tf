variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "sku" {
  type    = string
  default = "VpnGw1AZ"
}

variable "subnet_id" {
  description = "ID of the GatewaySubnet."
  type        = string
}

variable "zones" {
  type    = list(string)
  default = ["1", "2", "3"]
}

variable "vpn_client_address_space" {
  description = "P2S client pool; empty list disables point-to-site."
  type        = list(string)
  default     = []
}

variable "tenant_id" {
  description = "Entra tenant ID for P2S AAD authentication. Read from provider context when empty."
  type        = string
  default     = ""
}

variable "onprem_gateways" {
  description = "Site-to-site VPN devices, keyed by connection name."
  type = map(object({
    gateway_address = string
    address_space   = list(string)
  }))
  default = {}
}

variable "onprem_shared_keys" {
  description = "IPsec pre-shared keys, keyed by the same names as onprem_gateways."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
