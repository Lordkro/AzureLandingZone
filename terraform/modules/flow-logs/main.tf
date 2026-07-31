# ---------------------------------------------------------------------------
# VNet flow logs + Traffic Analytics.
#
# VNet flow logs supersede NSG flow logs (which Microsoft is retiring) and
# capture traffic for every NIC in the virtual network, including subnets with
# no NSG attached. Traffic Analytics processes them into the workspace so you
# can see denied flows, top talkers and malicious IP hits without parsing JSON.
#
# Prerequisite: a Network Watcher must exist in the region. Azure normally
# auto-creates NetworkWatcher_<region> in NetworkWatcherRG the first time a
# virtual network is created in the subscription.
# ---------------------------------------------------------------------------

data "azurerm_network_watcher" "this" {
  name                = var.network_watcher_name
  resource_group_name = var.network_watcher_resource_group_name
}

# Dedicated account: flow logs are high-volume and write-heavy, and mixing them
# with application data makes lifecycle rules and access control awkward.
resource "azurerm_storage_account" "flow_logs" {
  name                = var.storage_account_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = true

  # The flow log writer authenticates with the account key, so shared-key access
  # cannot be disabled here (unlike the workload storage account). Access is
  # instead constrained by the network rules below.
  shared_access_key_enabled = true

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices", "Logging", "Metrics"]
    ip_rules       = var.storage_allowed_ip_rules
  }

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }
}

# Flow log blobs are only useful while an investigation is open; Traffic
# Analytics keeps the aggregated view in the workspace.
resource "azurerm_storage_management_policy" "expire_flow_logs" {
  storage_account_id = azurerm_storage_account.flow_logs.id

  rule {
    name    = "expire-flow-logs"
    enabled = true

    filters {
      prefix_match = ["insights-logs-flowlogflowevent"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = var.retention_days
      }
    }
  }
}

resource "azurerm_network_watcher_flow_log" "this" {
  for_each = var.virtual_network_ids

  name                 = "fl-${each.key}"
  network_watcher_name = data.azurerm_network_watcher.this.name
  resource_group_name  = data.azurerm_network_watcher.this.resource_group_name
  location             = var.location
  target_resource_id   = each.value
  storage_account_id   = azurerm_storage_account.flow_logs.id
  enabled              = true
  version              = 2
  tags                 = var.tags

  retention_policy {
    enabled = true
    days    = var.retention_days
  }

  traffic_analytics {
    enabled               = var.traffic_analytics_enabled
    workspace_id          = var.log_analytics_workspace_customer_id
    workspace_region      = var.log_analytics_workspace_location
    workspace_resource_id = var.log_analytics_workspace_id
    interval_in_minutes   = var.traffic_analytics_interval_in_minutes
  }
}
