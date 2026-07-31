resource "azurerm_storage_account" "this" {
  # Queue logging: this account exists for blob workload data and the platform
  # creates no queues. Setting queue_properties would also force the provider onto
  # the storage data plane on every plan, which fails for a deployment identity
  # that holds control-plane Owner but no data-plane role — the exact shape of the
  # CI identity in docs/deployment.md.
  #checkov:skip=CKV_AZURE_33:No queue service is used; enabling queue_properties would require data-plane access the deployment identity does not have.
  # Customer-managed keys are a deliberate follow-up, not an oversight: they move
  # the durability of this account onto a key whose loss is unrecoverable, and the
  # platform Key Vault is created in the same stack behind a private endpoint. See
  # docs/governance.md for the intended shape (key + storage identity + Key Vault
  # Crypto Service Encryption User + azurerm_storage_account_customer_managed_key).
  #checkov:skip=CKV2_AZURE_1:Platform-managed keys are the deliberate default; CMK is documented as an opt-in follow-up in docs/governance.md rather than forced on every consumer.
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  account_tier             = "Standard"
  account_replication_type = var.replication_type
  account_kind             = "StorageV2"
  access_tier              = "Hot"

  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false
  default_to_oauth_authentication = true

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
}

resource "azurerm_private_endpoint" "blob" {
  name                = "pep-${var.name}-blob"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${var.name}-blob"
    private_connection_resource_id = azurerm_storage_account.this.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }
}

resource "azurerm_monitor_diagnostic_setting" "blob" {
  name                       = "diag-${var.name}-blob"
  target_resource_id         = "${azurerm_storage_account.this.id}/blobServices/default"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "audit"
  }

  enabled_metric {
    category = "Transaction"
  }
}
