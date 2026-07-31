# Naming conventions

Pattern: `<type>-<workload/scope>-<prefix>-<environment>-<region>` using [CAF abbreviations](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations).

With `prefix = contoso`, `environment = prod`, `location_short = weu`:

| Resource | Abbrev. | Example |
|---|---|---|
| Management group | `mg` | `mg-contoso`, `mg-contoso-connectivity` |
| Resource group | `rg` | `rg-hub-contoso-prod-weu` |
| Virtual network | `vnet` | `vnet-hub-contoso-prod-weu` |
| Subnet | `snet` | `snet-workload` |
| NSG | `nsg` | `nsg-workload` |
| Route table | `rt` | `rt-vnet-spoke-contoso-prod-weu` |
| Azure Firewall | `afw` | `afw-contoso-prod-weu` |
| Firewall policy | `afwp` | `afwp-afw-contoso-prod-weu` |
| DDoS protection plan | `ddos` | `ddos-contoso-prod-weu` |
| Bastion | `bas` | `bas-contoso-prod-weu` |
| VPN gateway | `vgw` | `vgw-contoso-prod-weu` |
| Local network gateway | `lgw` | `lgw-headoffice` |
| Connection | `con` | `con-headoffice` |
| Public IP | `pip` | `pip-afw-contoso-prod-weu` |
| Log Analytics | `log` | `log-contoso-prod-weu` |
| Data collection rule | `dcr` | `dcr-vm-log-contoso-prod-weu` |
| Action group | `ag` | `ag-platform-contoso-prod-weu` |
| Alert rule | `alert` | `alert-firewall-snat-contoso-prod-weu` |
| Budget | `budget` | `budget-contoso-prod-weu` |
| Flow log | `fl` | `fl-hub` |
| Management lock | `lock` | `lock-hub-no-delete` |
| Key Vault | `kv` | `kv-contoso-prod-x7k2p9` * |
| Storage account | `st` | `stcontosoprodx7k2p9` * |
| Flow log storage | `stfl` | `stflcontosoprodx7k2p9` * |
| App Gateway | `agw` | `agw-contoso-prod-weu` |
| WAF policy | `waf` | `waf-agw-contoso-prod-weu` |
| Private endpoint | `pep` | `pep-kv-contoso-prod-x7k2p9` |
| Maintenance config | `mc` | `mc-contoso-prod-weu` |

\* Key Vault and storage names are globally unique, so they carry a random/deterministic suffix instead of the region code (storage additionally forbids hyphens, 24-char max).

Fixed names required by Azure (do not rename): `AzureFirewallSubnet`, `GatewaySubnet`, `AzureBastionSubnet`, and `NetworkWatcherRG` / `NetworkWatcher_<region>`.

Action group **short names** are capped at 12 characters and appear as the sender on SMS and email — `plat<environment>` by default.

## Custom role names

Custom roles are not prefixed: they appear in the portal's role picker alongside built-ins, so a readable display name matters more than a naming pattern.

| Role | Display name |
|---|---|
| Platform owner | `Azure Platform Owner` |
| Network operations | `Network Management (NetOps)` |
| Security operations | `Security Operations (SecOps)` |
| Landing zone owner | `Subscription Owner` |
| Workload owner | `Application Owner (DevOps)` |

## Tags

Required on every resource group (enforced by policy, inherited to resources):

| Tag | Purpose |
|---|---|
| `workload` | What it belongs to |
| `environment` | prod / dev / test |
| `managed_by` | terraform / bicep — flags IaC-owned resources |
| `cost_center`, `owner` | Recommended additions |

The `patch-schedule` tag on VMs (value `default`) enrols them into the Update Manager maintenance window. Both the tag name and value are configurable (`patch_tag` / `patchTagName` + `patchTagValue`).
