# Azure Landing Zone (CAF-aligned)

Production-ready Azure Landing Zone following the [Microsoft Cloud Adoption Framework](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/), implemented twice — in **Terraform** and in **Bicep** — with GitHub Actions CI/CD. Pick the IaC flavour your team standardises on; both deploy the same architecture.

## What gets deployed

| Area | Components |
|---|---|
| **Organisation** | CAF management group hierarchy — Platform (Identity/Management/Connectivity), Landing Zones (Corp/Online), Sandbox, Decommissioned — plus subscription placement *(opt-in)* |
| **Networking** | Hub-spoke VNets with peering, forced tunnelling (UDR 0.0.0.0/0 → firewall), NSGs on every subnet (including Bastion's documented rule set and the private endpoint subnet), optional DDoS Network Protection |
| **Security edge** | Azure Firewall (Standard/Premium, DNS proxy, threat intel deny, baseline rules), Azure Bastion (Standard, native client), WAF_v2 Application Gateway (OWASP 3.2, Prevention, TLS 1.2 floor, TLS-only from the internet) |
| **Hybrid connectivity** | VPN Gateway (zone-redundant `VpnGw1AZ`), optional P2S with Entra ID auth, optional S2S IPsec connections |
| **DNS** | Private DNS zones for Key Vault, Storage, SQL, Web Apps, ACR and the full Azure Monitor private-link set + hub/spoke links |
| **Management** | Log Analytics workspace (with ingestion cap), AMA data collection rule, diagnostic settings on every resource, **subscription activity log → workspace** |
| **Observability** | Platform action group, Service Health / Resource Health / role-assignment alerts, firewall health + SNAT and App Gateway backend metric alerts |
| **Network visibility** | VNet flow logs + Traffic Analytics on hub and spoke *(opt-in)* |
| **Security posture** | Microsoft Defender for Cloud (7 plans), security contact with escalation phone, workspace routing |
| **Governance** | Azure Policy baseline — allowed locations, required/inherited tags, storage HTTPS + public-access, Key Vault purge protection + firewall, deny public IPs on NICs, blocked resource types, AMA install and DCR association with remediation identities |
| **Access control** | Five custom platform roles (Platform Owner, NetOps, SecOps, Subscription Owner, Application Owner) + RBAC assignments |
| **Cost** | Subscription budget with actual and forecast alerts *(opt-in)* |
| **Resilience** | CanNotDelete locks on the hub, management and security resource groups |
| **Patching** | Azure Update Manager maintenance window + dynamic scope (tag-driven VM enrolment) |
| **Data services** | Key Vault (RBAC, purge protection, private endpoint), Storage (GZRS, OAuth-only, versioning, private endpoint) |

## Repository layout

```
├── terraform/              # Terraform implementation (azurerm ~> 4.30)
│   ├── main.tf             # Root module — wires everything together
│   ├── variables.tf        # All inputs, sane production defaults
│   ├── .tflint.hcl
│   ├── terraform.tfvars.example
│   └── modules/            # 19 self-contained modules
├── bicep/                  # Bicep implementation (subscription-scope)
│   ├── main.bicep          # Orchestration template
│   ├── main.bicepparam     # Parameter file
│   ├── managementGroups.bicep  # Tenant-scope hierarchy (separate deployment)
│   └── modules/            # Matching module set
├── .github/workflows/
│   ├── terraform.yml       # lint/scan → validate → plan (PR comment) → apply (gated)
│   ├── bicep.yml           # lint/scan → validate → what-if (PR comment) → deploy (gated)
│   └── management-groups.yml  # Manual tenant-scope hierarchy deployment
└── docs/
    ├── architecture.md     # Topology, IPAM, design decisions
    ├── deployment.md       # Bootstrap, OIDC setup, first deploy
    ├── governance.md       # Policy, RBAC, Defender, Update Manager, cost
    └── naming.md           # Naming conventions (CAF abbreviations)
```

## Quick start

1. **Bootstrap** — create the state backend + OIDC app registration: [docs/deployment.md](docs/deployment.md)
2. **Configure** — copy `terraform/terraform.tfvars.example` → `terraform.tfvars` (or edit `bicep/main.bicepparam`)
3. **Deploy locally** (first run) or push to `main` and let the pipeline apply:

```bash
# Terraform
cd terraform
terraform init -backend-config=backend.hcl
terraform plan -out tfplan
terraform apply tfplan
```

```bash
# Bicep
az deployment sub create \
  --location westeurope \
  --template-file bicep/main.bicep \
  --parameters bicep/main.bicepparam
```

> **Heads-up:** the VPN Gateway takes 30–45 minutes to provision on first deploy. Azure Firewall, Bastion and Application Gateway each carry meaningful monthly cost — review [docs/architecture.md](docs/architecture.md#cost-considerations) before deploying to a sandbox subscription.

### Opt-in components

These are off by default because they need broader permissions, extra prerequisites, or cost money at a different order of magnitude. Enable them deliberately:

| Component | Terraform | Bicep | Why it is off |
|---|---|---|---|
| Management groups | `enable_management_groups` | separate `managementGroups.bicep` deployment | Needs Tenant Root Group permissions |
| DDoS Network Protection | `enable_ddos_protection` | `enableDdosProtection` | ~USD 3k/month flat, per tenant not per landing zone |
| VNet flow logs + Traffic Analytics | `enable_flow_logs` | `enableFlowLogs` | Needs a regional Network Watcher; adds ingestion cost |
| Budget | `monthly_budget_amount` | `monthlyBudgetAmount` | No sensible default amount |

## CI/CD

Both workflows authenticate with **OIDC federated credentials** (no stored secrets), lint and security-scan (`tflint` / Bicep linter, Checkov → GitHub Security tab — the repo scans clean on both frameworks; see [governance.md](docs/governance.md#static-analysis-checkov) for the handful of documented suppressions), post the plan/what-if as a PR comment, and gate `apply`/`deploy` behind the `production` GitHub environment so a human approves every change to `main`. A nightly scheduled run detects configuration drift. Required repository secrets are listed in [docs/deployment.md](docs/deployment.md#github-configuration).

Management group changes run from a **separate, manual workflow** — they are tenant scoped and need a broader grant than the landing zone pipeline.

## Documentation

- [Architecture & network design](docs/architecture.md)
- [Deployment guide](docs/deployment.md)
- [Governance: Policy, RBAC, Defender, patching, cost](docs/governance.md)
- [Naming conventions](docs/naming.md)
