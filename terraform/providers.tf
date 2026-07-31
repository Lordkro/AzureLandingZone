terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.30"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Remote state — configure via backend.hcl or -backend-config CLI flags.
  # See docs/deployment.md for bootstrap instructions.
  backend "azurerm" {}
}

provider "azurerm" {
  # azurerm v4 requires an explicit subscription. CI supplies it through
  # ARM_SUBSCRIPTION_ID; setting the variable is only needed for local runs
  # against a subscription other than the CLI default.
  subscription_id = var.subscription_id

  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
  storage_use_azuread = true
}
