@description('Hub virtual network with firewall, gateway, bastion and shared-services subnets.')
param name string
param location string
param addressSpace array
param firewallSubnetPrefix string
param gatewaySubnetPrefix string
param bastionSubnetPrefix string
param sharedServicesPrefix string

@description('DDoS Network Protection plan to attach. Empty leaves the VNet on the free Basic tier.')
param ddosProtectionPlanId string = ''

param logAnalyticsWorkspaceId string
param tags object = {}

resource sharedServicesNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-shared-services'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'DenyInboundInternet'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: addressSpace
    }
    enableDdosProtection: !empty(ddosProtectionPlanId)
    ddosProtectionPlan: empty(ddosProtectionPlanId)
      ? null
      : {
          id: ddosProtectionPlanId
        }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: firewallSubnetPrefix
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: gatewaySubnetPrefix
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetPrefix
        }
      }
      {
        name: 'snet-shared-services'
        properties: {
          addressPrefix: sharedServicesPrefix
          privateEndpointNetworkPolicies: 'Enabled'
          networkSecurityGroup: {
            id: sharedServicesNsg.id
          }
        }
      }
    ]
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${name}'
  scope: vnet
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output firewallSubnetId string = vnet.properties.subnets[0].id
output gatewaySubnetId string = vnet.properties.subnets[1].id
output bastionSubnetId string = vnet.properties.subnets[2].id
output sharedServicesSubnetId string = vnet.properties.subnets[3].id
