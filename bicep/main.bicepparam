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

// --- Management & security ---------------------------------------------------
param logRetentionDays = 90
param securityContactEmail = 'security@contoso.com'
param allowedLocations = ['westeurope', 'northeurope']

// --- RBAC ---------------------------------------------------------------------
// Built-in role GUIDs: Contributor b24988ac-6180-42a0-ab88-20f7382dd24c,
// Reader acdd72a7-3385-48ef-bd42-f606fba81ae7, Security Reader 39bc4728-0917-49c7-9d2c-d95423bc2eb4
param rbacAssignments = [
  // {
  //   principalId: '00000000-0000-0000-0000-000000000000' // AAD group object ID
  //   roleDefinitionId: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
  //   principalType: 'Group'
  // }
]

param keyVaultAdminObjectIds = [
  // '00000000-0000-0000-0000-000000000000'
]
