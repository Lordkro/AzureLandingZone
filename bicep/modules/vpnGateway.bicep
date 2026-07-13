@description('Route-based VPN gateway with optional point-to-site (Entra ID auth) and site-to-site connections.')
param name string
param location string
param sku string = 'VpnGw1AZ'
param subnetId string
param zones array = [
  '1'
  '2'
  '3'
]
@description('P2S client pool; empty array disables point-to-site.')
param vpnClientAddressSpace array = []
@description('Site-to-site connections: array of { name, gatewayAddress, addressSpace, sharedKey }.')
@secure()
param onpremGateways object = {}
param logAnalyticsWorkspaceId string
param tags object = {}

var tenantId = tenant().tenantId
var onpremNames = objectKeys(onpremGateways)

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-${name}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  zones: zones
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource gateway 'Microsoft.Network/virtualNetworkGateways@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    vpnGatewayGeneration: 'Generation1'
    activeActive: false
    enableBgp: false
    sku: {
      name: sku
      tier: sku
    }
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    vpnClientConfiguration: empty(vpnClientAddressSpace)
      ? null
      : {
          vpnClientAddressPool: {
            addressPrefixes: vpnClientAddressSpace
          }
          vpnClientProtocols: [
            'OpenVPN'
          ]
          vpnAuthenticationTypes: [
            'AAD'
          ]
          aadTenant: 'https://login.microsoftonline.com/${tenantId}/'
          aadAudience: '41b23e61-6c1e-4545-b367-cd054e0ed4b4' // Azure VPN Client app ID
          aadIssuer: 'https://sts.windows.net/${tenantId}/'
        }
  }
}

resource localGateways 'Microsoft.Network/localNetworkGateways@2024-05-01' = [
  for gw in onpremNames: {
    name: 'lgw-${gw}'
    location: location
    tags: tags
    properties: {
      gatewayIpAddress: onpremGateways[gw].gatewayAddress
      localNetworkAddressSpace: {
        addressPrefixes: onpremGateways[gw].addressSpace
      }
    }
  }
]

resource connections 'Microsoft.Network/connections@2024-05-01' = [
  for (gw, i) in onpremNames: {
    name: 'con-${gw}'
    location: location
    tags: tags
    properties: {
      connectionType: 'IPsec'
      connectionProtocol: 'IKEv2'
      virtualNetworkGateway1: {
        id: gateway.id
        properties: {}
      }
      localNetworkGateway2: {
        id: localGateways[i].id
        properties: {}
      }
      sharedKey: onpremGateways[gw].sharedKey
      dpdTimeoutSeconds: 45
    }
  }
]

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${name}'
  scope: gateway
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

output gatewayId string = gateway.id
output publicIpAddress string = publicIp.properties.ipAddress
