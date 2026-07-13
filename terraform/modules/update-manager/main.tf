# Azure Update Manager maintenance configuration for guest OS patching.
resource "azurerm_maintenance_configuration" "this" {
  name                     = var.name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  scope                    = "InGuestPatch"
  in_guest_user_patch_mode = "Platform"
  tags                     = var.tags

  window {
    start_date_time = var.maintenance_window.start_date_time
    duration        = var.maintenance_window.duration
    time_zone       = "UTC"
    recur_every     = var.maintenance_window.recur_every
  }

  install_patches {
    reboot = "IfRequired"

    windows {
      classifications_to_include = ["Critical", "Security", "UpdateRollup", "Definition"]
    }

    linux {
      classifications_to_include = ["Critical", "Security"]
    }
  }
}

# Attach every VM in the subscription carrying the opt-in tag to the window.
resource "azurerm_maintenance_assignment_dynamic_scope" "tagged_vms" {
  name                         = "mads-${var.name}"
  maintenance_configuration_id = azurerm_maintenance_configuration.this.id

  filter {
    resource_types = ["Microsoft.Compute/virtualMachines"]
    tag_filter     = "All"

    tags {
      tag    = var.patch_tag_name
      values = [var.patch_tag_value]
    }
  }
}
