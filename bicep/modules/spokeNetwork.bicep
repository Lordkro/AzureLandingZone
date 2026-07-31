@description('Workload spoke virtual network with NSGs and forced tunnelling through Azure Firewall.')
param name string
param location string
param addressSpace array
param workloadSubnetPrefix string
param appGatewaySubnetPrefix string
param privateEndpointsPrefix string
param firewallPrivateIp string

@description('DDoS Network Protection plan to attach. Empty leaves the VNet on the free Basic tier.')
param ddosProtectionPlanId string = ''

param logAnalyticsWorkspaceId string
param tags object = {}

resource workloadNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-workload'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowAppGatewayInbound'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '80'
            '443'
          ]
          sourceAddressPrefix: appGatewaySubnetPrefix
          destinationAddressPrefix: workloadSubnetPrefix
        }
      }
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

resource appGatewayNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-appgw'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowGatewayManager'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '65200-65535'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
        }
      }
      // TLS only from the internet. The gateway's default HTTP listener is
      // therefore not reachable from outside — deliberately, it is a placeholder
      // (see appGateway.bicep). If you add an HTTP listener that redirects to
      // HTTPS, add a matching rule for port 80 at priority 111. It is written out
      // rather than made a parameter on purpose: a conditional rule reads as
      // "port 80 open" to every static scanner, which costs the guarantee that
      // this subnet is TLS-only by default.
      {
        name: 'AllowHttpsInbound'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowAzureLoadBalancer'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// Private endpoints honour NSG rules only because the subnet sets
// privateEndpointNetworkPolicies: 'Enabled' below. Without that flag this NSG
// would be silently ignored.
resource privateEndpointsNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-private-endpoints'
  location: location
  tags: tags
  properties: {
    securityRules: [
      // Only the spoke and on-premises (via the hub) should reach a private endpoint.
      {
        name: 'AllowVnetInbound'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource routeTable 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'rt-${name}'
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'default-via-firewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
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
        name: 'snet-workload'
        properties: {
          addressPrefix: workloadSubnetPrefix
          networkSecurityGroup: {
            id: workloadNsg.id
          }
          routeTable: {
            id: routeTable.id
          }
        }
      }
      {
        name: 'snet-appgw'
        properties: {
          addressPrefix: appGatewaySubnetPrefix
          networkSecurityGroup: {
            id: appGatewayNsg.id
          }
        }
      }
      {
        name: 'snet-private-endpoints'
        properties: {
          addressPrefix: privateEndpointsPrefix
          privateEndpointNetworkPolicies: 'Enabled'
          networkSecurityGroup: {
            id: privateEndpointsNsg.id
          }
          routeTable: {
            id: routeTable.id
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
output workloadSubnetId string = vnet.properties.subnets[0].id
output appGatewaySubnetId string = vnet.properties.subnets[1].id
output privateEndpointsSubnetId string = vnet.properties.subnets[2].id
