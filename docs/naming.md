# Naming conventions

Pattern: `<type>-<workload/scope>-<prefix>-<environment>-<region>` using [CAF abbreviations](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations).

With `prefix = contoso`, `environment = prod`, `location_short = weu`:

| Resource | Abbrev. | Example |
|---|---|---|
| Resource group | `rg` | `rg-hub-contoso-prod-weu` |
| Virtual network | `vnet` | `vnet-hub-contoso-prod-weu` |
| Subnet | `snet` | `snet-workload` |
| NSG | `nsg` | `nsg-workload` |
| Route table | `rt` | `rt-vnet-spoke-contoso-prod-weu` |
| Azure Firewall | `afw` | `afw-contoso-prod-weu` |
| Firewall policy | `afwp` | `afwp-afw-contoso-prod-weu` |
| Bastion | `bas` | `bas-contoso-prod-weu` |
| VPN gateway | `vgw` | `vgw-contoso-prod-weu` |
| Local network gateway | `lgw` | `lgw-headoffice` |
| Connection | `con` | `con-headoffice` |
| Public IP | `pip` | `pip-afw-contoso-prod-weu` |
| Log Analytics | `log` | `log-contoso-prod-weu` |
| Data collection rule | `dcr` | `dcr-vm-log-contoso-prod-weu` |
| Key Vault | `kv` | `kv-contoso-prod-x7k2p9` * |
| Storage account | `st` | `stcontosoprodx7k2p9` * |
| App Gateway | `agw` | `agw-contoso-prod-weu` |
| WAF policy | `waf` | `waf-agw-contoso-prod-weu` |
| Private endpoint | `pep` | `pep-kv-contoso-prod-x7k2p9` |
| Maintenance config | `mc` | `mc-contoso-prod-weu` |

\* Key Vault and storage names are globally unique, so they carry a random/deterministic suffix instead of the region code (storage additionally forbids hyphens, 24-char max).

Fixed names required by Azure (do not rename): `AzureFirewallSubnet`, `GatewaySubnet`, `AzureBastionSubnet`.

## Tags

Required on every resource group (enforced by policy, inherited to resources):

| Tag | Purpose |
|---|---|
| `workload` | What it belongs to |
| `environment` | prod / dev / test |
| `managed_by` | terraform / bicep — flags IaC-owned resources |
| `cost_center`, `owner` | Recommended additions |

The `patch-schedule` tag on VMs (value `default`) enrols them into the Update Manager maintenance window.
