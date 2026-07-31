// ---------------------------------------------------------------------------
// VNet flow logs + Traffic Analytics.
//
// VNet flow logs supersede NSG flow logs (which Microsoft is retiring) and
// capture traffic for every NIC in the virtual network, including subnets with
// no NSG attached. Traffic Analytics processes them into the workspace so you
// can see denied flows, top talkers and malicious IP hits without parsing JSON.
//
// This module is deployed into the Network Watcher's resource group (normally
// NetworkWatcherRG) because flow logs are child resources of the watcher.
// ---------------------------------------------------------------------------

@description('Name of the regional Network Watcher, e.g. NetworkWatcher_westeurope.')
param networkWatcherName string

param location string

@description('Array of { name, id } for the virtual networks to log.')
param virtualNetworks array

param storageAccountId string
param retentionDays int = 90

param trafficAnalyticsEnabled bool = true

@allowed([
  10
  60
])
param trafficAnalyticsIntervalInMinutes int = 60

@description('Workspace (customer) GUID.')
param logAnalyticsWorkspaceCustomerId string

@description('Workspace resource ID.')
param logAnalyticsWorkspaceId string

@description('Region of the workspace.')
param logAnalyticsWorkspaceLocation string

param tags object = {}

resource networkWatcher 'Microsoft.Network/networkWatchers@2024-05-01' existing = {
  name: networkWatcherName
}

resource flowLogs 'Microsoft.Network/networkWatchers/flowLogs@2024-05-01' = [
  for vnet in virtualNetworks: {
    parent: networkWatcher
    name: 'fl-${vnet.name}'
    location: location
    tags: tags
    properties: {
      targetResourceId: vnet.id
      storageId: storageAccountId
      enabled: true
      format: {
        type: 'JSON'
        version: 2
      }
      retentionPolicy: {
        enabled: true
        days: retentionDays
      }
      flowAnalyticsConfiguration: {
        networkWatcherFlowAnalyticsConfiguration: {
          enabled: trafficAnalyticsEnabled
          workspaceId: logAnalyticsWorkspaceCustomerId
          workspaceRegion: logAnalyticsWorkspaceLocation
          workspaceResourceId: logAnalyticsWorkspaceId
          trafficAnalyticsInterval: trafficAnalyticsIntervalInMinutes
        }
      }
    }
  }
]

output flowLogIds array = [for (vnet, i) in virtualNetworks: flowLogs[i].id]
