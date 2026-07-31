resource "azurerm_public_ip" "this" {
  name                = "pip-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.zones
  tags                = var.tags
}

resource "azurerm_firewall_policy" "this" {
  name                     = "afwp-${var.name}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  sku                      = var.sku_tier
  threat_intelligence_mode = "Deny"
  tags                     = var.tags

  dns {
    proxy_enabled = true
  }

  dynamic "intrusion_detection" {
    for_each = var.sku_tier == "Premium" ? [1] : []
    content {
      mode = "Deny"
    }
  }
}

resource "azurerm_firewall_policy_rule_collection_group" "platform" {
  name               = "rcg-platform"
  firewall_policy_id = azurerm_firewall_policy.this.id
  priority           = 200

  network_rule_collection {
    name     = "allow-core-azure"
    priority = 200
    action   = "Allow"

    rule {
      name                  = "azure-monitor"
      protocols             = ["TCP"]
      source_addresses      = var.spoke_address_space
      destination_addresses = ["AzureMonitor"]
      destination_ports     = ["443"]
    }

    rule {
      name              = "azure-kms-activation"
      protocols         = ["TCP"]
      source_addresses  = var.spoke_address_space
      destination_fqdns = ["kms.core.windows.net", "azkms.core.windows.net"]
      destination_ports = ["1688"]
    }

    rule {
      name              = "ntp"
      protocols         = ["UDP"]
      source_addresses  = var.spoke_address_space
      destination_fqdns = ["time.windows.com"]
      destination_ports = ["123"]
    }
  }

  application_rule_collection {
    name     = "allow-platform-fqdns"
    priority = 300
    action   = "Allow"

    rule {
      name             = "windows-update"
      source_addresses = var.spoke_address_space
      protocols {
        type = "Https"
        port = 443
      }
      protocols {
        type = "Http"
        port = 80
      }
      destination_fqdn_tags = ["WindowsUpdate", "WindowsDiagnostics", "MicrosoftActiveProtectionService"]
    }

    rule {
      name             = "azure-services"
      source_addresses = var.spoke_address_space
      protocols {
        type = "Https"
        port = 443
      }
      destination_fqdns = [
        "*.azure.com",
        "*.microsoft.com",
        "*.microsoftonline.com",
        "*.windows.net",
        "*.azure-automation.net",
      ]
    }

    rule {
      name             = "linux-package-repos"
      source_addresses = var.spoke_address_space
      protocols {
        type = "Https"
        port = 443
      }
      protocols {
        type = "Http"
        port = 80
      }
      destination_fqdns = [
        "*.ubuntu.com",
        "azure.archive.ubuntu.com",
        "packages.microsoft.com",
      ]
    }
  }
}

resource "azurerm_firewall" "this" {
  # CKV_AZURE_216 inspects `threat_intel_mode` on this resource, which only exists
  # on classic (rule-based) firewalls. This is a policy-based firewall, where the
  # setting lives on azurerm_firewall_policy above as threat_intelligence_mode =
  # "Deny" — and azurerm rejects both being set at once. The control is on; the
  # check is looking at the wrong resource for this topology.
  #checkov:skip=CKV_AZURE_216:Policy-based firewall — threat intel Deny is set on azurerm_firewall_policy.threat_intelligence_mode, and the two settings are mutually exclusive.
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_name            = "AZFW_VNet"
  sku_tier            = var.sku_tier
  firewall_policy_id  = azurerm_firewall_policy.this.id
  zones               = var.zones
  tags                = var.tags

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = var.subnet_id
    public_ip_address_id = azurerm_public_ip.this.id
  }

  depends_on = [azurerm_firewall_policy_rule_collection_group.platform]
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  name                           = "diag-${var.name}"
  target_resource_id             = azurerm_firewall.this.id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
