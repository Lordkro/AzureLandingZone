# Azure Landing Zone (CAF-aligned)

Production-ready Azure Landing Zone following the [Microsoft Cloud Adoption Framework](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/), implemented twice — in **Terraform** and in **Bicep** — with GitHub Actions CI/CD. Pick the IaC flavour your team standardises on; both deploy the same architecture.

## What gets deployed

| Area | Components |
|---|---|
| **Networking** | Hub-spoke VNets with peering, forced tunnelling (UDR 0.0.0.0/0 → firewall), NSGs |
| **Security edge** | Azure Firewall (Standard/Premium, DNS proxy, threat intel deny, baseline rules), Azure Bastion (Standard, native client), WAF_v2 Application Gateway (OWASP 3.2, Prevention) |
| **Hybrid connectivity** | VPN Gateway (zone-redundant `VpnGw1AZ`), optional P2S with Entra ID auth, optional S2S IPsec connections |
| **DNS** | Private DNS zones for Key Vault, Storage, SQL, Web Apps, ACR + hub/spoke links |
| **Management** | Log Analytics workspace, AMA data collection rule, diagnostic settings on every resource |
| **Security posture** | Microsoft Defender for Cloud (7 plans), security contact, workspace routing |
| **Governance** | Azure Policy baseline (allowed locations, required/inherited tags, HTTPS-only storage, KV purge protection, periodic update assessment), RBAC assignments |
| **Patching** | Azure Update Manager maintenance window + dynamic scope (tag-driven VM enrolment) |
| **Data services** | Key Vault (RBAC, purge protection, private endpoint), Storage (ZRS, OAuth-only, versioning, private endpoint) |

## Repository layout

```
├── terraform/              # Terraform implementation (azurerm ~> 4.30)
│   ├── main.tf             # Root module — wires everything together
│   ├── variables.tf        # All inputs, sane production defaults
│   ├── terraform.tfvars.example
│   └── modules/            # 14 self-contained modules
├── bicep/                  # Bicep implementation (subscription-scope)
│   ├── main.bicep          # Orchestration template
│   ├── main.bicepparam     # Parameter file
│   └── modules/            # Matching module set
├── .github/workflows/
│   ├── terraform.yml       # fmt → validate → plan (PR comment) → apply (gated)
│   └── bicep.yml           # lint → validate → what-if (PR comment) → deploy (gated)
└── docs/
    ├── architecture.md     # Topology, IPAM, design decisions
    ├── deployment.md       # Bootstrap, OIDC setup, first deploy
    ├── governance.md       # Policy, RBAC, Defender, Update Manager
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

# Bicep
az deployment sub create \
  --location westeurope \
  --template-file bicep/main.bicep \
  --parameters bicep/main.bicepparam
```

> **Heads-up:** the VPN Gateway takes 30–45 minutes to provision on first deploy. Azure Firewall, Bastion and Application Gateway each carry meaningful monthly cost — review [docs/architecture.md](docs/architecture.md#cost-considerations) before deploying to a sandbox subscription.

## CI/CD

Both workflows authenticate with **OIDC federated credentials** (no stored secrets), post the plan/what-if as a PR comment, and gate `apply`/`deploy` behind the `production` GitHub environment so a human approves every change to `main`. Required repository secrets are listed in [docs/deployment.md](docs/deployment.md#github-configuration).

## Documentation

- [Architecture & network design](docs/architecture.md)
- [Deployment guide](docs/deployment.md)
- [Governance: Policy, RBAC, Defender, patching](docs/governance.md)
- [Naming conventions](docs/naming.md)
