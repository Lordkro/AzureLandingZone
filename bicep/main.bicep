targetScope = 'subscription'

// ---------------------------------------------------------------------------
// CAF-aligned Azure Landing Zone — subscription-scope orchestration.
// ---------------------------------------------------------------------------

@description('Organisation / workload prefix (lowercase alphanumeric).')
@minLength(2)
@maxLength(8)
param prefix string = 'alz'

@description('Environment name.')
param environment string = 'prod'

@description('Primary Azure region.')
param location string = 'westeurope'

@description('Short region code used in names.')
param locationShort string = 'weu'

param tags object = {
  workload: 'landing-zone'
  managed_by: 'bicep'
}

// Networking
param hubAddressSpace array = ['10.0.0.0/16']
param hubFirewallSubnet string = '10.0.1.0/26'
param hubGatewaySubnet string = '10.0.2.0/27'
param hubBastionSubnet string = '10.0.3.0/26'
param hubSharedServicesSubnet string = '10.0.4.0/24'

param spokeAddressSpace array = ['10.1.0.0/16']
param spokeWorkloadSubnet string = '10.1.1.0/24'
param spokeAppGatewaySubnet string = '10.1.2.0/24'
param spokePrivateEndpointsSubnet string = '10.1.3.0/24'

@allowed(['Standard', 'Premium'])
param firewallSkuTier string = 'Standard'
param vpnGatewaySku string = 'VpnGw1AZ'
param vpnClientAddressSpace array = []
@secure()
param onpremGateways object = {}

param privateDnsZones array = [
  'privatelink.vaultcore.azure.net'
  'privatelink.blob.core.windows.net'
  'privatelink.file.core.windows.net'
  'privatelink.queue.core.windows.net'
  'privatelink.table.core.windows.net'
  'privatelink.database.windows.net'
  'privatelink.azurewebsites.net'
  'privatelink.azurecr.io'
]

// Management & security
param logRetentionDays int = 90
param securityContactEmail string = 'security@example.com'
param defenderPlans array = [
  'VirtualMachines'
  'StorageAccounts'
  'KeyVaults'
  'Arm'
  'Containers'
  'AppServices'
  'SqlServers'
]
param allowedLocations array = ['westeurope', 'northeurope']
param requiredTags array = ['workload', 'environment']

@description('Update Manager window start, UTC ("yyyy-MM-dd HH:mm").')
param maintenanceStartDateTime string = '2026-08-01 02:00'

// RBAC & workload services
@description('Array of { principalId, roleDefinitionId (GUID), principalType }.')
param rbacAssignments array = []
param keyVaultAdminObjectIds array = []
param appGatewayAutoscaleMin int = 1
param appGatewayAutoscaleMax int = 3

// ---------------------------------------------------------------------------

var suffix = '${prefix}-${environment}-${locationShort}'
var uniqueSuffix = substring(uniqueString(subscription().subscriptionId, prefix, environment), 0, 6)
var allTags = union(tags, { environment: environment })

resource hubRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-hub-${suffix}'
  location: location
  tags: allTags
}

resource spokeRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-spoke-${suffix}'
  location: location
  tags: allTags
}

resource mgmtRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-mgmt-${suffix}'
  location: location
  tags: allTags
}

resource securityRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-sec-${suffix}'
  location: location
  tags: allTags
}

// --- Management ------------------------------------------------------------

module logAnalytics 'modules/logAnalytics.bicep' = {
  scope: mgmtRg
  name: 'deploy-log-analytics'
  params: {
    name: 'log-${suffix}'
    location: location
    retentionInDays: logRetentionDays
    tags: allTags
  }
}

// --- Hub -------------------------------------------------------------------

module hubNetwork 'modules/hubNetwork.bicep' = {
  scope: hubRg
  name: 'deploy-hub-network'
  params: {
    name: 'vnet-hub-${suffix}'
    location: location
    addressSpace: hubAddressSpace
    firewallSubnetPrefix: hubFirewallSubnet
    gatewaySubnetPrefix: hubGatewaySubnet
    bastionSubnetPrefix: hubBastionSubnet
    sharedServicesPrefix: hubSharedServicesSubnet
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    tags: allTags
  }
}

module firewall 'modules/firewall.bicep' = {
  scope: hubRg
  name: 'deploy-firewall'
  params: {
    name: 'afw-${suffix}'
    location: location
    skuTier: firewallSkuTier
    subnetId: hubNetwork.outputs.firewallSubnetId
    spokeAddressSpace: spokeAddressSpace
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    tags: allTags
  }
}

module bastion 'modules/bastion.bicep' = {
  scope: hubRg
  name: 'deploy-bastion'
  params: {
    name: 'bas-${suffix}'
    location: location
    subnetId: hubNetwork.outputs.bastionSubnetId
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    tags: allTags
  }
}

module vpnGateway 'modules/vpnGateway.bicep' = {
  scope: hubRg
  name: 'deploy-vpn-gateway'
  params: {
    name: 'vgw-${suffix}'
    location: location
    sku: vpnGatewaySku
    subnetId: hubNetwork.outputs.gatewaySubnetId
    vpnClientAddressSpace: vpnClientAddressSpace
    onpremGateways: onpremGateways
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    tags: allTags
  }
}

// --- Spoke -----------------------------------------------------------------

module spokeNetwork 'modules/spokeNetwork.bicep' = {
  scope: spokeRg
  name: 'deploy-spoke-network'
  params: {
    name: 'vnet-spoke-${suffix}'
    location: location
    addressSpace: spokeAddressSpace
    workloadSubnetPrefix: spokeWorkloadSubnet
    appGatewaySubnetPrefix: spokeAppGatewaySubnet
    privateEndpointsPrefix: spokePrivateEndpointsSubnet
    firewallPrivateIp: firewall.outputs.privateIpAddress
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    tags: allTags
  }
}

module hubToSpokePeering 'modules/vnetPeering.bicep' = {
  scope: hubRg
  name: 'deploy-peer-hub-to-spoke'
  params: {
    localVnetName: hubNetwork.outputs.vnetName
    peeringName: 'peer-hub-to-spoke'
    remoteVnetId: spokeNetwork.outputs.vnetId
    allowGatewayTransit: true
  }
  dependsOn: [
    vpnGateway
  ]
}

module spokeToHubPeering 'modules/vnetPeering.bicep' = {
  scope: spokeRg
  name: 'deploy-peer-spoke-to-hub'
  params: {
    localVnetName: spokeNetwork.outputs.vnetName
    peeringName: 'peer-spoke-to-hub'
    remoteVnetId: hubNetwork.outputs.vnetId
    useRemoteGateways: true
  }
  dependsOn: [
    hubToSpokePeering
  ]
}

module privateDns 'modules/privateDns.bicep' = {
  scope: hubRg
  name: 'deploy-private-dns'
  params: {
    zones: privateDnsZones
    virtualNetworks: [
      {
        name: 'hub'
        id: hubNetwork.outputs.vnetId
      }
      {
        name: 'spoke'
        id: spokeNetwork.outputs.vnetId
      }
    ]
    tags: allTags
  }
}

// --- Governance & security --------------------------------------------------

module defender 'modules/defender.bicep' = {
  name: 'deploy-defender'
  params: {
    plans: defenderPlans
    securityContactEmail: securityContactEmail
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
  }
}

module policy 'modules/policy.bicep' = {
  name: 'deploy-policy'
  params: {
    location: location
    allowedLocations: allowedLocations
    requiredTags: requiredTags
  }
}

module updateManager 'modules/updateManager.bicep' = {
  scope: mgmtRg
  name: 'deploy-update-manager'
  params: {
    name: 'mc-${suffix}'
    location: location
    startDateTime: maintenanceStartDateTime
    tags: allTags
  }
}

module updateManagerScope 'modules/updateManagerScope.bicep' = {
  name: 'deploy-update-manager-scope'
  params: {
    name: 'mads-mc-${suffix}'
    maintenanceConfigurationId: updateManager.outputs.maintenanceConfigurationId
  }
}

module rbac 'modules/rbac.bicep' = {
  name: 'deploy-rbac'
  params: {
    assignments: rbacAssignments
  }
}

// --- Workload services -------------------------------------------------------

module keyVault 'modules/keyVault.bicep' = {
  scope: securityRg
  name: 'deploy-key-vault'
  params: {
    name: 'kv-${prefix}-${environment}-${uniqueSuffix}'
    location: location
    adminObjectIds: keyVaultAdminObjectIds
    privateEndpointSubnetId: spokeNetwork.outputs.privateEndpointsSubnetId
    privateDnsZoneId: first(filter(privateDns.outputs.zoneIds, z => z.name == 'privatelink.vaultcore.azure.net')).id
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    tags: allTags
  }
}

module storage 'modules/storage.bicep' = {
  scope: spokeRg
  name: 'deploy-storage'
  params: {
    name: 'st${prefix}${environment}${uniqueSuffix}'
    location: location
    privateEndpointSubnetId: spokeNetwork.outputs.privateEndpointsSubnetId
    privateDnsZoneId: first(filter(privateDns.outputs.zoneIds, z => z.name == 'privatelink.blob.core.windows.net')).id
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    tags: allTags
  }
}

module appGateway 'modules/appGateway.bicep' = {
  scope: spokeRg
  name: 'deploy-app-gateway'
  params: {
    name: 'agw-${suffix}'
    location: location
    subnetId: spokeNetwork.outputs.appGatewaySubnetId
    autoscaleMin: appGatewayAutoscaleMin
    autoscaleMax: appGatewayAutoscaleMax
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    tags: allTags
  }
}

// ---------------------------------------------------------------------------

output hubVnetId string = hubNetwork.outputs.vnetId
output spokeVnetId string = spokeNetwork.outputs.vnetId
output firewallPrivateIp string = firewall.outputs.privateIpAddress
output firewallPublicIp string = firewall.outputs.publicIpAddress
output bastionFqdn string = bastion.outputs.dnsName
output vpnGatewayPublicIp string = vpnGateway.outputs.publicIpAddress
output logAnalyticsWorkspaceId string = logAnalytics.outputs.workspaceId
output keyVaultUri string = keyVault.outputs.vaultUri
output storageAccountName string = storage.outputs.storageAccountName
output appGatewayPublicIp string = appGateway.outputs.publicIpAddress
