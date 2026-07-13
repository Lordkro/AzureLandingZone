# Governance

## Azure Policy baseline

Assigned at subscription scope (module `policy`):

| Assignment | Built-in definition | Effect |
|---|---|---|
| `allowed-locations` | Allowed locations | Deny |
| `require-tag-*` | Require a tag on resource groups | Deny (one per required tag) |
| `inherit-tag-*` | Inherit a tag from the resource group | Modify + remediation identity |
| `storage-https-only` | Secure transfer to storage accounts | Audit |
| `audit-unmanaged-disks` | Audit VMs without managed disks | Audit |
| `kv-purge-protection` | Key vaults should have purge protection | Audit |
| `periodic-update-checks` | Configure periodic checking for missing updates | Modify + remediation identity |

Modify-effect assignments get a system-assigned identity with the role needed to remediate (Contributor for tags, VM Contributor for update assessment). Trigger remediation for existing resources:

```bash
az policy remediation create --name remediate-tags \
  --policy-assignment inherit-tag-workload
```

**Management groups**: this repo assigns policy at subscription scope, which suits a single-subscription landing zone. At enterprise scale, move the assignments up to a CAF management group hierarchy (`Platform` / `Landing Zones` / `Sandbox` / `Decommissioned`) — the policy module parameters translate directly; only the assignment scope changes. Deploying management groups requires Tenant Root Group permissions and is deliberately out of scope here.

## RBAC model

Grant roles to **Entra ID groups, never individual users**, via the `rbac` module:

| Group (suggested) | Role | Scope |
|---|---|---|
| `sg-platform-admins` | Owner | Subscription (break-glass, PIM-eligible only) |
| `sg-platform-engineers` | Contributor | Subscription |
| `sg-network-ops` | Network Contributor | `rg-hub` |
| `sg-security-team` | Security Reader + Key Vault Administrator | Subscription / vault |
| `sg-workload-devs` | Contributor | `rg-spoke` only |

Recommendations:
- Use **PIM (Privileged Identity Management)** for Owner/Contributor — standing access should be Reader.
- Data-plane access (storage blobs, Key Vault secrets) is separate from control plane; assign `Storage Blob Data *` / `Key Vault Secrets User` explicitly.
- The GitHub OIDC identity is the only principal that should routinely hold write access; humans review its PRs.

## Microsoft Defender for Cloud

Enabled at Standard tier for: Virtual Machines (P2), Storage, Key Vault, ARM, Containers, App Services, SQL. Alerts email the configured security contact for High severity and notify Owners. Security data routes to the central Log Analytics workspace.

To add continuous export to Sentinel/Event Hub, extend the `defender` module with `azurerm_security_center_automation` (Terraform) or `Microsoft.Security/automations` (Bicep).

## Azure Update Manager

- **Maintenance window**: Sundays 02:00–05:55 UTC by default (`maintenance_window` variable).
- **Patch classifications**: Windows — Critical, Security, UpdateRollup, Definition; Linux — Critical, Security.
- **Reboot**: `IfRequired`.
- **Enrolment is tag-driven**: any VM tagged `patch-schedule = default` is picked up by the dynamic scope — no per-VM configuration.
- The `periodic-update-checks` policy sets every VM's assessment mode to `AutomaticByPlatform`, so compliance data appears even for unenrolled machines.

VM prerequisites: patch orchestration `AutomaticByPlatform` (the policy remediates this) and outbound access to Windows Update / package repos — already allowed in the firewall's platform rule collection.

## Monitoring & diagnostics

- Every deployed resource ships diagnostics to the central workspace (`allLogs` or `audit` category groups + metrics).
- Azure Firewall uses **resource-specific** (Dedicated) tables — query `AZFWApplicationRule`, `AZFWNetworkRule`, `AZFWDnsQuery`.
- The AMA data collection rule (`dcr-vm-*`) collects perf counters, Windows System/Application/Security events and Linux syslog. Associate it with VMs at creation time or via policy (`Configure Windows/Linux virtual machines to be associated with a Data Collection Rule`).
- Suggested alert rules to add next: firewall threat-intel hits, Bastion session anomalies, policy compliance drops, workspace ingestion cap approaching.
