targetScope = 'subscription'

// ---------------------------------------------------------------------------
// CAF-aligned Azure Landing Zone — subscription-scope orchestration.
//
// Management groups are tenant-scoped and therefore live in a separate template
// (bicep/managementGroups.bicep) deployed before this one. See docs/governance.md.
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

@description('Create a DDoS Network Protection plan and attach hub + spoke. Flat ~USD 3k/month per tenant — enable once, not per landing zone.')
param enableDdosProtection bool = false

param privateDnsZones array = [
  'privatelink.vaultcore.azure.net'
  'privatelink.blob.core.windows.net'
  'privatelink.file.core.windows.net'
  'privatelink.queue.core.windows.net'
  'privatelink.table.core.windows.net'
  'privatelink.database.windows.net'
  'privatelink.azurewebsites.net'
  'privatelink.azurecr.io'
  // Azure Monitor private link set — required for Azure Monitor Agent ingestion
  // and Log Analytics queries once egress is locked down. These four plus the
  // blob zone above form the complete set; a partial set silently breaks agent
  // ingestion.
  'privatelink.monitor.azure.com'
  'privatelink.oms.opinsights.azure.com'
  'privatelink.ods.opinsights.azure.com'
  'privatelink.agentsvc.azure-automation.net'
]

// Management & security
param logRetentionDays int = 90

@description('Daily workspace ingestion cap in GB. -1 = unlimited; cap it in non-prod.')
param logDailyQuotaGb int = -1

param securityContactEmail string = 'security@example.com'

@description('Additional email addresses added to the platform action group.')
param platformAlertEmails array = []

@description('Webhook URIs (Teams, PagerDuty, ...) added to the platform action group.')
param platformAlertWebhooks array = []

param defenderPlans array = [
  'VirtualMachines'
  'StorageAccounts'
  'KeyVaults'
  'Arm'
  'Containers'
  'AppServices'
  'SqlServers'
]

@description('Apply CanNotDelete locks to the hub, management and security resource groups.')
param enableResourceLocks bool = true

// Policy
param allowedLocations array = ['westeurope', 'northeurope']
param requiredTags array = ['workload', 'environment']

@description('Resource types blocked outright. Empty skips the assignment.')
param deniedResourceTypes array = []

@description('Deny public IPs on NICs — they bypass the hub firewall and forced-tunnelling routes.')
param denyPublicIpOnNic bool = true

@allowed(['Audit', 'Deny', 'Disabled'])
param storagePublicAccessEffect string = 'Audit'

@description('Assign the policies that install Azure Monitor Agent and bind VMs to the platform data collection rule.')
param deployAzureMonitorAgent bool = true

// Flow logs
@description('Enable VNet flow logs with Traffic Analytics. Requires a Network Watcher in the region.')
param enableFlowLogs bool = false

@description('Network Watcher name. Empty derives NetworkWatcher_<location>.')
param networkWatcherName string = ''

param networkWatcherResourceGroupName string = 'NetworkWatcherRG'
param flowLogRetentionDays int = 90

// Patching
@description('Update Manager window start, UTC ("yyyy-MM-dd HH:mm").')
param maintenanceStartDateTime string = '2026-08-01 02:00'

@description('Maintenance window length, "HH:mm" (max 03:55).')
param maintenanceDuration string = '03:55'

@description('Recurrence, e.g. "1Week Sunday" or "1Day".')
param maintenanceRecurEvery string = '1Week Sunday'

@description('Tag name that enrols a VM into the maintenance window.')
param patchTagName string = 'patch-schedule'

@description('Tag value that enrols a VM into the maintenance window.')
param patchTagValue string = 'default'

// Cost management
@description('Monthly budget in the billing currency. 0 disables the budget and its alerts.')
param monthlyBudgetAmount int = 0

@description('Budget start — first of a month.')
param budgetStartDate string = '2026-08-01T00:00:00Z'

param budgetEndDate string = '2030-08-01T00:00:00Z'

// RBAC & workload services
@description('Create the platform custom role definitions (Azure Platform Owner, NetOps, SecOps, Subscription Owner, Application Owner).')
param enableCustomRoles bool = true

@description('Array of { principalId, roleDefinitionId (GUID), principalType }.')
param rbacAssignments array = []
param keyVaultAdminObjectIds array = []
param appGatewayAutoscaleMin int = 1
param appGatewayAutoscaleMax int = 3

// ---------------------------------------------------------------------------

var suffix = '${prefix}-${environment}-${locationShort}'
var uniqueSuffix = substring(uniqueString(subscription().subscriptionId, prefix, environment), 0, 6)
var allTags = union(tags, { environment: environment })

// The security contact is always included so Defender and Azure Monitor
// notifications land in the same place.
var alertEmails = union([securityContactEmail], platformAlertEmails)

var resolvedNetworkWatcherName = empty(networkWatcherName) ? 'NetworkWatcher_${location}' : networkWatcherName

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
    dailyQuotaGb: logDailyQuotaGb
    tags: allTags
  }
}

// The subscription activity log is the audit trail for every control-plane
// operation — without this it is only retained for 90 days and cannot be
// correlated with resource logs.
module activityLog 'modules/activityLog.bicep' = {
  name: 'deploy-activity-log'
  params: {
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
  }
}

// --- Hub -------------------------------------------------------------------

module ddosPlan 'modules/ddosProtectionPlan.bicep' = if (enableDdosProtection) {
  scope: hubRg
  name: 'deploy-ddos-plan'
  params: {
    name: 'ddos-${suffix}'
    location: location
    tags: allTags
  }
}

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
    ddosProtectionPlanId: enableDdosProtection ? ddosPlan!.outputs.planId : ''
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
    ddosProtectionPlanId: enableDdosProtection ? ddosPlan!.outputs.planId : ''
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

// --- Flow logs ---------------------------------------------------------------

module flowLogsStorage 'modules/flowLogsStorage.bicep' = if (enableFlowLogs) {
  scope: mgmtRg
  name: 'deploy-flow-logs-storage'
  params: {
    name: 'stfl${prefix}${environment}${uniqueSuffix}'
    location: location
    retentionDays: flowLogRetentionDays
    tags: allTags
  }
}

// Flow logs are child resources of the Network Watcher, which lives in its own
// resource group (Azure creates NetworkWatcherRG automatically).
resource networkWatcherRg 'Microsoft.Resources/resourceGroups@2024-03-01' existing = if (enableFlowLogs) {
  name: networkWatcherResourceGroupName
}

module flowLogs 'modules/flowLogs.bicep' = if (enableFlowLogs) {
  scope: networkWatcherRg
  name: 'deploy-flow-logs'
  params: {
    networkWatcherName: resolvedNetworkWatcherName
    location: location
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
    storageAccountId: enableFlowLogs ? flowLogsStorage!.outputs.storageAccountId : ''
    retentionDays: flowLogRetentionDays
    logAnalyticsWorkspaceCustomerId: logAnalytics.outputs.workspaceCustomerId
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    logAnalyticsWorkspaceLocation: location
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
    deniedResourceTypes: deniedResourceTypes
    denyPublicIpOnNic: denyPublicIpOnNic
    storagePublicAccessEffect: storagePublicAccessEffect
    deployAzureMonitorAgent: deployAzureMonitorAgent
    dataCollectionRuleId: logAnalytics.outputs.vmDataCollectionRuleId
  }
}

module customRoles 'modules/customRoles.bicep' = if (enableCustomRoles) {
  name: 'deploy-custom-roles'
  params: {
    assignableScopes: [
      subscription().id
    ]
  }
}

module updateManager 'modules/updateManager.bicep' = {
  scope: mgmtRg
  name: 'deploy-update-manager'
  params: {
    name: 'mc-${suffix}'
    location: location
    startDateTime: maintenanceStartDateTime
    duration: maintenanceDuration
    recurEvery: maintenanceRecurEvery
    tags: allTags
  }
}

module updateManagerScope 'modules/updateManagerScope.bicep' = {
  name: 'deploy-update-manager-scope'
  params: {
    name: 'mads-mc-${suffix}'
    maintenanceConfigurationId: updateManager.outputs.maintenanceConfigurationId
    patchTagName: patchTagName
    patchTagValue: patchTagValue
  }
}

module rbac 'modules/rbac.bicep' = {
  name: 'deploy-rbac'
  params: {
    assignments: rbacAssignments
  }
}

// --- Resource locks ----------------------------------------------------------
// Platform groups should not be deletable by accident — a deleted hub takes
// every spoke's egress path with it. The spoke workload group is deliberately
// left unlocked so teams can tear down and rebuild their own resources.

module hubLock 'modules/resourceGroupLock.bicep' = if (enableResourceLocks) {
  scope: hubRg
  name: 'deploy-lock-hub'
  params: {
    name: 'lock-hub-no-delete'
  }
}

module mgmtLock 'modules/resourceGroupLock.bicep' = if (enableResourceLocks) {
  scope: mgmtRg
  name: 'deploy-lock-mgmt'
  params: {
    name: 'lock-management-no-delete'
  }
}

module securityLock 'modules/resourceGroupLock.bicep' = if (enableResourceLocks) {
  scope: securityRg
  name: 'deploy-lock-security'
  params: {
    name: 'lock-security-no-delete'
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

// --- Platform alerting & cost control ----------------------------------------

module alerts 'modules/alerts.bicep' = {
  scope: mgmtRg
  name: 'deploy-alerts'
  params: {
    suffix: suffix
    // Action group short names are capped at 12 characters.
    actionGroupShortName: substring('plat${environment}', 0, min(12, length('plat${environment}')))
    notificationEmails: alertEmails
    notificationWebhooks: platformAlertWebhooks
    serviceHealthLocations: allowedLocations
    firewallId: firewall.outputs.firewallId
    appGatewayId: appGateway.outputs.appGatewayId
    tags: allTags
  }
}

module budget 'modules/budget.bicep' = if (monthlyBudgetAmount > 0) {
  name: 'deploy-budget'
  params: {
    name: 'budget-${suffix}'
    amount: monthlyBudgetAmount
    startDate: budgetStartDate
    endDate: budgetEndDate
    contactEmails: alertEmails
    actionGroupIds: [
      alerts.outputs.actionGroupId
    ]
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
output dataCollectionRuleId string = logAnalytics.outputs.vmDataCollectionRuleId
output keyVaultUri string = keyVault.outputs.vaultUri
output storageAccountName string = storage.outputs.storageAccountName
output appGatewayPublicIp string = appGateway.outputs.publicIpAddress
output actionGroupId string = alerts.outputs.actionGroupId
output ddosProtectionPlanId string = enableDdosProtection ? ddosPlan!.outputs.planId : ''
