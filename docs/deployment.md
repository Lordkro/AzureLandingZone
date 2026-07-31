# Deployment guide

## Prerequisites

- Azure subscription with **Owner** role (policy + role assignments need it)
- Azure CLI ≥ 2.60, Terraform ≥ 1.9 and/or Bicep CLI ≥ 0.30
- For management groups: **Owner** or **Management Group Contributor on the Tenant Root Group**
- Resource providers registered:

```bash
for rp in Microsoft.Network Microsoft.Security Microsoft.Maintenance Microsoft.Insights \
          Microsoft.OperationalInsights Microsoft.KeyVault Microsoft.Storage \
          Microsoft.AlertsManagement Microsoft.Consumption Microsoft.Authorization \
          Microsoft.Management; do
  az provider register --namespace $rp
done
```

## 1. Bootstrap the Terraform state backend

One-off, done outside Terraform (chicken-and-egg):

```bash
LOCATION=westeurope
RG=rg-tfstate-prod
SA=sttfstate$RANDOM$RANDOM   # must be globally unique

az group create --name $RG --location $LOCATION
az storage account create --name $SA --resource-group $RG \
  --sku Standard_ZRS --kind StorageV2 \
  --min-tls-version TLS1_2 --allow-blob-public-access false
az storage container create --name tfstate --account-name $SA --auth-mode login
```

Create `terraform/backend.hcl` (git-ignored):

```hcl
resource_group_name  = "rg-tfstate-prod"
storage_account_name = "<SA name from above>"
container_name       = "tfstate"
key                  = "landing-zone.tfstate"
use_azuread_auth     = true
```

## 2. Create the deployment identity (OIDC — no secrets)

```bash
SUB_ID=$(az account show --query id -o tsv)
APP_ID=$(az ad app create --display-name "github-alz-deploy" --query appId -o tsv)
az ad sp create --id $APP_ID
az role assignment create --assignee $APP_ID --role Owner --scope /subscriptions/$SUB_ID
```

> Owner is required because the deployment creates role assignments (policy remediation identities, custom role definitions, RBAC module). If that's unacceptable, split governance into a separately-permissioned pipeline and drop to Contributor + User Access Administrator.

If you are deploying the management group hierarchy, grant the same identity at tenant root — separately, and deliberately:

```bash
az role assignment create --assignee $APP_ID \
  --role "Management Group Contributor" \
  --scope /providers/Microsoft.Management/managementGroups/$(az account show --query tenantId -o tsv)
```

Federated credentials for GitHub Actions (replace `ORG/REPO`):

```bash
az ad app federated-credential create --id $APP_ID --parameters '{
  "name": "github-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:ORG/REPO:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'
az ad app federated-credential create --id $APP_ID --parameters '{
  "name": "github-pr",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:ORG/REPO:pull_request",
  "audiences": ["api://AzureADTokenExchange"]
}'
az ad app federated-credential create --id $APP_ID --parameters '{
  "name": "github-env-production",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:ORG/REPO:environment:production",
  "audiences": ["api://AzureADTokenExchange"]
}'
```

Grant the identity data access to the state container:

```bash
az role assignment create --assignee $APP_ID \
  --role "Storage Blob Data Contributor" \
  --scope $(az storage account show -n $SA -g $RG --query id -o tsv)
```

## GitHub configuration

**Repository secrets** (Settings → Secrets and variables → Actions):

| Secret | Value |
|---|---|
| `AZURE_CLIENT_ID` | App registration client ID |
| `AZURE_TENANT_ID` | Entra tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Target subscription ID |
| `TFSTATE_RESOURCE_GROUP` | `rg-tfstate-prod` |
| `TFSTATE_STORAGE_ACCOUNT` | State storage account name |

**Environment**: create a `production` environment with **required reviewers**. The `apply`, `deploy` and management-group jobs reference it, so every change to `main` needs a human approval before touching Azure.

**Branch protection** on `main`: require the Terraform/Bicep checks to pass and require review from code owners (see `.github/CODEOWNERS` — replace the placeholder team names first).

## 3. Optional: deploy the management group hierarchy

Tenant scoped, so it is a **separate deployment that runs before** the landing zone.

```bash
# Bicep — preview first
az deployment tenant what-if \
  --name alz-management-groups \
  --location westeurope \
  --template-file bicep/managementGroups.bicep \
  --parameters prefix=contoso displayName=Contoso
```

```bash
az deployment tenant create \
  --name alz-management-groups \
  --location westeurope \
  --template-file bicep/managementGroups.bicep \
  --parameters prefix=contoso displayName=Contoso
```

Terraform builds the hierarchy inside the main stack instead — set `enable_management_groups = true`.

Either way, expect a few minutes of eventual consistency before the new groups are visible to policy and RBAC.

## 4. First deployment

### Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # edit values
terraform init -backend-config=backend.hcl
terraform plan -out tfplan
terraform apply tfplan
```

### Bicep

```bash
az deployment sub create \
  --name alz-initial \
  --location westeurope \
  --template-file bicep/main.bicep \
  --parameters bicep/main.bicepparam
```

Expect **45–60 minutes** on first run (VPN Gateway ~40 min, Firewall ~10 min, App Gateway ~10 min).

## 5. Post-deployment checklist

- [ ] Verify spoke egress: a test VM in `snet-workload` should reach the internet only through the firewall (check `AZFWApplicationRule` logs in Log Analytics).
- [ ] Connect Bastion to the test VM (portal or `az network bastion ssh`).
- [ ] If P2S enabled: grant users the Azure VPN Client enterprise app, download the profile from the gateway.
- [ ] Tag VMs with `patch-schedule = default` to enrol them in the Update Manager window.
- [ ] Confirm Defender plans show **On** in Defender for Cloud → Environment settings.
- [ ] Review policy compliance after ~30 min (Policy → Compliance), then run remediation tasks for the Modify/DeployIfNotExists assignments — see [governance.md](governance.md#remediating-existing-resources).
- [ ] Confirm the activity log is arriving: `AzureActivity | take 10` in the workspace.
- [ ] Confirm a test VM picked up Azure Monitor Agent and the DCR association (VM → Extensions, and `Heartbeat | where Computer == "<name>"`).
- [ ] Send a test notification to the action group: Monitor → Alerts → Action groups → `ag-platform-*` → Test.
- [ ] Store the S2S shared keys in the deployed Key Vault; never in tfvars/bicepparam committed to git.
- [ ] Replace the placeholder team names in `.github/CODEOWNERS`.

## Local checks before pushing

```bash
pip install pre-commit && pre-commit install
pre-commit run --all-files
```

This runs `terraform fmt`, `terraform validate`, `tflint` and `az bicep build` — the same gates the pipeline enforces.

## Operational notes

- **State locking**: the azurerm backend uses blob leases automatically — no extra configuration. The workflow also serialises runs with a `concurrency` group so two applies queue instead of colliding.
- **Provider lock file**: `terraform/.terraform.lock.hcl` is committed on purpose. Deleting or gitignoring it means CI can silently resolve a different provider version than you tested with. It carries checksums for `linux_amd64`, `windows_amd64` and `darwin_arm64` so a lock generated on a laptop still verifies on the Linux runner. After bumping a provider, regenerate all three:

```bash
cd terraform
terraform init -upgrade
terraform providers lock -platform=linux_amd64 -platform=windows_amd64 -platform=darwin_arm64
```

- **Drift**: both workflows run nightly (`schedule`) and fail if the deployed estate no longer matches `main`.
- **Choose one IaC track** for a given subscription. Running both against the same subscription will fight over the same resource names.
- **Destroy order**: `terraform destroy` handles ordering and removes its own resource group locks first. With Bicep you must delete the `CanNotDelete` locks by hand. Key Vault purge protection means the vault name is unavailable for 90 days after deletion.
- **Plan artifacts** contain resource attributes. They are retained for 5 days and never leave the repository's artifact storage; treat the retention setting as a security control, not housekeeping.
