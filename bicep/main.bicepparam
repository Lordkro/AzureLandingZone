using 'main.bicep'

param prefix = 'contoso'
param environment = 'prod'
param location = 'westeurope'
param locationShort = 'weu'

param tags = {
  workload: 'landing-zone'
  managed_by: 'bicep'
  cost_center: 'platform'
  owner: 'platform-team@contoso.com'
}

// --- Networking -------------------------------------------------------------
param hubAddressSpace = ['10.0.0.0/16']
param spokeAddressSpace = ['10.1.0.0/16']

param firewallSkuTier = 'Premium'
param vpnGatewaySku = 'VpnGw1AZ'

// Flat ~USD 3k/month per tenant — enable once, not per landing zone.
param enableDdosProtection = false

// Point-to-site VPN (optional; empty disables)
param vpnClientAddressSpace = ['172.16.0.0/24']

// Site-to-site connections (optional). Inject the shared key at deploy time,
// e.g. --parameters onpremGateways="$ONPREM_GATEWAYS_JSON"
// param onpremGateways = {
//   headoffice: {
//     gatewayAddress: '203.0.113.10'
//     addressSpace: ['192.168.0.0/16']
//     sharedKey: '<from-key-vault-or-pipeline-secret>'
//   }
// }

// --- Flow logs ---------------------------------------------------------------
// Needs a Network Watcher in the region; adds storage + ingestion cost.
param enableFlowLogs = false
param flowLogRetentionDays = 90

// --- Management & security ---------------------------------------------------
param logRetentionDays = 90
param logDailyQuotaGb = -1 // cap this in non-prod, e.g. 5
param securityContactEmail = 'security@contoso.com'
param platformAlertEmails = ['platform-oncall@contoso.com']
// param platformAlertWebhooks = ['https://contoso.webhook.office.com/...']
param enableResourceLocks = true

// --- Policy ------------------------------------------------------------------
param allowedLocations = ['westeurope', 'northeurope']

// Start at Audit, switch to Deny once existing workloads comply.
param storagePublicAccessEffect = 'Audit'
param denyPublicIpOnNic = true
param deployAzureMonitorAgent = true

// param deniedResourceTypes = [
//   'Microsoft.ClassicCompute/virtualMachines'
//   'Microsoft.ClassicNetwork/virtualNetworks'
// ]

// --- Patching ----------------------------------------------------------------
param maintenanceStartDateTime = '2026-08-01 02:00'
param maintenanceDuration = '03:55'
param maintenanceRecurEvery = '1Week Sunday'
param patchTagName = 'patch-schedule'
param patchTagValue = 'default'

// --- Cost management ---------------------------------------------------------
// 0 disables the budget and its alerts.
param monthlyBudgetAmount = 0
param budgetStartDate = '2026-08-01T00:00:00Z'
param budgetEndDate = '2030-08-01T00:00:00Z'

// --- RBAC ---------------------------------------------------------------------
param enableCustomRoles = true

// Built-in role GUIDs: Contributor b24988ac-6180-42a0-ab88-20f7382dd24c,
// Reader acdd72a7-3385-48ef-bd42-f606fba81ae7, Security Reader 39bc4728-0917-49c7-9d2c-d95423bc2eb4
// Custom roles created by modules/customRoles.bicep are reported in the
// deployment output — take their GUIDs from there to assign them here.
param rbacAssignments = [
  // {
  //   principalId: '00000000-0000-0000-0000-000000000000' // Entra group object ID
  //   roleDefinitionId: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
  //   principalType: 'Group'
  // }
]

param keyVaultAdminObjectIds = [
  // '00000000-0000-0000-0000-000000000000'
]
