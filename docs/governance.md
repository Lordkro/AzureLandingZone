# Governance

## Management groups

The CAF hierarchy is created by `modules/management-groups` (Terraform, `enable_management_groups = true`) or `bicep/managementGroups.bicep` (a **separate tenant-scoped deployment** — a subscription-scoped template cannot create management groups):

```
Tenant Root Group
└── mg-<prefix>                     intermediate root
    ├── mg-<prefix>-platform
    │   ├── mg-<prefix>-identity        Entra Domain Services, identity workloads
    │   ├── mg-<prefix>-management      Log Analytics, automation, backup vaults
    │   └── mg-<prefix>-connectivity    hub VNet, firewall, gateways, DNS
    ├── mg-<prefix>-landingzones
    │   ├── mg-<prefix>-corp            private workloads, on-prem connected
    │   └── mg-<prefix>-online          internet-facing workloads
    ├── mg-<prefix>-sandbox             loose policy, no connectivity
    └── mg-<prefix>-decommissioned      subscriptions on the way out
```

Off by default: creating management groups requires **Owner** or **Management Group Contributor on the Tenant Root Group**, which is a broader grant than a landing zone deployment identity normally holds. Bicep runs this through the manual `management-groups.yml` workflow for the same reason.

Place subscriptions with `management_group_subscription_placements` (a map of subscription GUID → hierarchy key) and `management_group_placement_for_this_subscription` for the subscription being deployed into.

**Policy scope**: this repo assigns policy at **subscription** scope, which suits a single-subscription landing zone and keeps the deployment identity's permissions narrow. Once the hierarchy exists and you are running multiple subscriptions, move the assignments up: the policy module's parameters translate unchanged, only the resource type changes (`azurerm_subscription_policy_assignment` → `azurerm_management_group_policy_assignment`, or `scope` on the Bicep `policyAssignments` resource). Assign at `mg-<prefix>` for estate-wide rules and at `corp` / `online` for tier-specific ones.

## Azure Policy baseline

Assigned at subscription scope (module `policy`):

| Assignment | Built-in definition | Effect | Notes |
|---|---|---|---|
| `allowed-locations` | Allowed locations | Deny | |
| `require-tag-*` | Require a tag on resource groups | Deny | one per required tag |
| `inherit-tag-*` | Inherit a tag from the resource group | Modify | remediation identity: Contributor |
| `not-allowed-resource-types` | Not allowed resource types | Deny | only when `denied_resource_types` is non-empty |
| `storage-https-only` | Secure transfer to storage accounts | Deny | |
| `storage-no-public-network` | Storage accounts should disable public network access | Audit → Deny | `storage_public_access_effect` |
| `kv-purge-protection` | Key vaults should have deletion protection | Audit | |
| `kv-firewall-enabled` | Key vaults should have firewall enabled | Audit | |
| `nic-no-public-ip` | Network interfaces should not have public IPs | Deny | `deny_public_ip_on_nic` |
| `security-contact-email` | Subscriptions should have a security contact | AuditIfNotExists | |
| `audit-unmanaged-disks` | Audit VMs without managed disks | Audit | |
| `periodic-update-checks` | Configure periodic checking for missing updates | Modify | remediation identity: Virtual Machine Contributor |
| `ama-windows` / `ama-linux` | Configure VMs to run Azure Monitor Agent | DeployIfNotExists | remediation identity: Virtual Machine Contributor |
| `dcr-windows` / `dcr-linux` | Associate VMs with a Data Collection Rule | DeployIfNotExists | remediation identities: Monitoring Contributor + Log Analytics Contributor |

### Why the AMA pair matters

The `log-analytics` module creates a data collection rule, but a DCR collects nothing on its own. The four AMA/DCR assignments install the agent and bind every Windows and Linux VM to that rule automatically — without them the DCR is inert and new VMs silently produce no telemetry. This is the single most common gap in a hand-rolled landing zone.

### Effects: start at Audit, move to Deny

`nic-no-public-ip` and `storage-https-only` deploy as **Deny** because a landing zone that allows either has no working perimeter. `storage-no-public-network` defaults to **Audit** so it does not break existing workloads on day one — check the compliance view, fix the offenders, then set `storage_public_access_effect = "Deny"`.

### Remediating existing resources

Modify and DeployIfNotExists assignments only act on *new or updated* resources until you trigger remediation:

```bash
az policy remediation create --name remediate-tags --policy-assignment inherit-tag-workload
```

```bash
az policy remediation create --name remediate-ama-windows --policy-assignment ama-windows --resource-discovery-mode ReEvaluateCompliance
```

### Verifying a built-in policy GUID

Policy definition IDs are hardcoded. Before adding one, confirm it:

```bash
az policy definition show --name <guid> --query "[displayName, parameters]"
```

## Custom roles

Module `custom-roles` (Terraform) / `customRoles.bicep` creates five definitions, modelled on the CAF enterprise-scale reference set. They exist because Owner/Contributor is too coarse — a network team needs write access to `Microsoft.Network/*` without the ability to grant itself more:

| Role | Grants | Explicitly denied |
|---|---|---|
| Azure Platform Owner | `*` | — (PIM-eligible only) |
| Network Management (NetOps) | read everything, full `Microsoft.Network/*`, deployments, diagnostics | everything else |
| Security Operations (SecOps) | read everything, `Microsoft.Security/*`, `Microsoft.SecurityInsights/*`, Log Analytics, alerting | everything else |
| Subscription Owner | `*` | role/policy writes, VPN and ExpressRoute gateways, route tables, peering |
| Application Owner (DevOps) | compute, web, AKS, storage, monitoring, tags, locks | role/policy writes, VNet and route table writes, peering |

When management groups are enabled the Terraform module creates the definitions at `mg-<prefix>` so one definition covers every subscription beneath it; otherwise they are subscription scoped. **Treat the permission lists as a starting point** and tighten them to your organisation — they are deliberately readable and editable in one place.

Assign them by display name:

```hcl
rbac_assignments = {
  network_ops = {
    principal_id         = "<Entra group object id>"
    role_definition_name = "Network Management (NetOps)"
  }
}
```

## RBAC model

Grant roles to **Entra ID groups, never individual users**, via the `rbac` module:

| Group (suggested) | Role | Scope |
|---|---|---|
| `sg-platform-admins` | Azure Platform Owner (custom) | Intermediate root MG (break-glass, PIM-eligible only) |
| `sg-platform-engineers` | Contributor | Subscription |
| `sg-network-ops` | Network Management (NetOps) (custom) | `rg-hub` or Connectivity MG |
| `sg-security-team` | Security Operations (SecOps) (custom) + Key Vault Administrator | Subscription / vault |
| `sg-workload-devs` | Application Owner (DevOps) (custom) | `rg-spoke` only |

Recommendations:
- Use **PIM (Privileged Identity Management)** for Owner/Platform Owner — standing access should be Reader.
- Data-plane access (storage blobs, Key Vault secrets) is separate from control plane; assign `Storage Blob Data *` / `Key Vault Secrets User` explicitly.
- The GitHub OIDC identity is the only principal that should routinely hold write access; humans review its PRs.
- Every role assignment at subscription scope raises the `alert-governance-changes-*` activity log alert.

## Microsoft Defender for Cloud

Enabled at Standard tier for: Virtual Machines (P2), Storage, Key Vault, ARM, Containers, App Services, SQL. Alerts email the configured security contact for High severity and notify Owners. Security data routes to the central Log Analytics workspace.

To add continuous export to Sentinel/Event Hub, extend the `defender` module with `azurerm_security_center_automation` (Terraform) or `Microsoft.Security/automations` (Bicep).

## Azure Update Manager

- **Maintenance window**: Sundays 02:00–05:55 UTC by default (`maintenance_window` / `maintenanceStartDateTime` + `maintenanceDuration` + `maintenanceRecurEvery`).
- **Patch classifications**: Windows — Critical, Security, UpdateRollup, Definition; Linux — Critical, Security.
- **Reboot**: `IfRequired`.
- **Enrolment is tag-driven**: any VM tagged `patch-schedule = default` is picked up by the dynamic scope — no per-VM configuration. Configurable via `patch_tag` / `patchTagName` + `patchTagValue`.
- The `periodic-update-checks` policy sets every VM's assessment mode to `AutomaticByPlatform`, so compliance data appears even for unenrolled machines.

VM prerequisites: patch orchestration `AutomaticByPlatform` (the policy remediates this) and outbound access to Windows Update / package repos — already allowed in the firewall's platform rule collection.

## Monitoring, alerting & diagnostics

- **Subscription activity log** ships to the central workspace (`Administrative`, `Security`, `ServiceHealth`, `Alert`, `Recommendation`, `Policy`, `Autoscale`, `ResourceHealth`). Without this the control-plane audit trail is capped at 90 days and cannot be joined to resource logs.
- Every deployed resource ships diagnostics to the workspace (`allLogs` or `audit` category groups + metrics).
- Azure Firewall uses **resource-specific** (Dedicated) tables — query `AZFWApplicationRule`, `AZFWNetworkRule`, `AZFWDnsQuery`.
- The AMA data collection rule (`dcr-vm-*`) collects perf counters, Windows System/Application/Security events and Linux syslog, and is bound to VMs by policy (see above).
- **Ingestion cap**: `log_daily_quota_gb` / `logDailyQuotaGb`. Leave at `-1` in production; cap it in non-prod, where a misconfigured diagnostic setting is the usual cause of a surprise bill.

### Alert rules

Module `monitoring` (Terraform) / `alerts.bicep` creates one action group (`ag-platform-*`) and wires these to it:

| Alert | Type | Fires when |
|---|---|---|
| `alert-service-health-*` | Activity log | Azure incident, planned maintenance or security advisory in an allowed region |
| `alert-resource-health-*` | Activity log | A resource goes Degraded/Unavailable, platform-initiated only |
| `alert-governance-changes-*` | Activity log | Role assignment written at subscription scope |
| `alert-firewall-health-*` | Metric | Firewall health state below 100% |
| `alert-firewall-snat-*` | Metric | SNAT port utilisation above 95% — silently drops outbound connections if ignored |
| `alert-appgw-unhealthy-hosts-*` | Metric | App Gateway backend failing health probes |

The action group ID is an output — reuse it for workload alerts instead of creating one per team.

## Network visibility

`enable_flow_logs` / `enableFlowLogs` turns on **VNet flow logs** (not NSG flow logs, which Microsoft is retiring) on hub and spoke, with **Traffic Analytics** processing them into the workspace. This is what lets you see denied flows, top talkers and malicious-IP hits without parsing JSON blobs.

Prerequisites and caveats:
- A Network Watcher must exist in the region. Azure normally auto-creates `NetworkWatcher_<region>` in `NetworkWatcherRG` when the first VNet is created. Override with `network_watcher_name` / `networkWatcherName`.
- Flow logs write with the storage account key, so that one account keeps `allowSharedKeyAccess = true` — deliberately unlike the workload storage account. Access is constrained by network rules instead.
- Raw blobs expire via a lifecycle rule after `flow_log_retention_days`; the aggregated view lives in the workspace.

## Cost management

- **Budget** (`monthly_budget_amount` / `monthlyBudgetAmount`, disabled by default) with actual alerts at 80% and 100% and a **forecast** alert at 100%. The forecast alert is the useful one — it fires before the money is gone. Notifications go to the platform action group and the alert email list.
- Budgets do not stop spend. They are the tripwire.
- The workspace ingestion cap is the other cost control worth setting deliberately.

## Resource locks

`enable_resource_locks` / `enableResourceLocks` (on by default) puts a `CanNotDelete` lock on `rg-hub`, `rg-mgmt` and `rg-sec`. A deleted hub takes every spoke's egress path with it. `rg-spoke` is deliberately **not** locked so workload teams can tear down and rebuild their own resources.

Terraform removes the lock before destroying the group, so this does not block `terraform destroy`. Bicep does not — remove the lock explicitly before deleting a locked group.
