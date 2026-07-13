# Deployment guide

## Prerequisites

- Azure subscription with **Owner** role (policy + role assignments need it)
- Azure CLI ≥ 2.60, Terraform ≥ 1.9 and/or Bicep CLI ≥ 0.30
- Resource providers registered: `Microsoft.Network`, `Microsoft.Security`, `Microsoft.Maintenance`, `Microsoft.Insights`, `Microsoft.OperationalInsights`, `Microsoft.KeyVault`, `Microsoft.Storage`

```bash
for rp in Microsoft.Network Microsoft.Security Microsoft.Maintenance Microsoft.Insights Microsoft.OperationalInsights Microsoft.KeyVault Microsoft.Storage; do
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

> Owner is required because the deployment creates role assignments (policy remediation identities, RBAC module). If that's unacceptable, split governance into a separately-permissioned pipeline and drop to Contributor + User Access Administrator.

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

**Environment**: create a `production` environment with **required reviewers**. Both `apply` and `deploy` jobs reference it, so every change to `main` needs a human approval before touching Azure.

## 3. First deployment

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

## 4. Post-deployment checklist

- [ ] Verify spoke egress: a test VM in `snet-workload` should reach the internet only through the firewall (check `AZFWApplicationRule` logs in Log Analytics).
- [ ] Connect Bastion to the test VM (portal or `az network bastion ssh`).
- [ ] If P2S enabled: grant users the Azure VPN Client enterprise app, download the profile from the gateway.
- [ ] Tag VMs with `patch-schedule = default` to enrol them in the Update Manager window.
- [ ] Confirm Defender plans show **On** in Defender for Cloud → Environment settings.
- [ ] Review policy compliance after ~30 min (Policy → Compliance).
- [ ] Store the S2S shared keys in the deployed Key Vault; never in tfvars/bicepparam committed to git.

## Operational notes

- **State locking**: the azurerm backend uses blob leases automatically — no extra configuration.
- **Drift**: run the plan job on a schedule (add `schedule:` trigger) to detect out-of-band changes.
- **Choose one IaC track** for a given subscription. Running both against the same subscription will fight over the same resource names.
- **Destroy order**: `terraform destroy` handles ordering, but Key Vault purge protection means the vault name is unavailable for 90 days after deletion.
