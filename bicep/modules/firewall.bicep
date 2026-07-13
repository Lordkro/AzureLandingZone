@description('Azure Firewall with firewall policy, DNS proxy and baseline platform rules.')
param name string
param location string
@allowed([
  'Standard'
  'Premium'
])
param skuTier string = 'Standard'
param subnetId string
param spokeAddressSpace array
param zones array = [
  '1'
  '2'
  '3'
]
param logAnalyticsWorkspaceId string
param tags object = {}

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

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2024-05-01' = {
  name: 'afwp-${name}'
  location: location
  tags: tags
  properties: {
    sku: {
      tier: skuTier
    }
    threatIntelMode: 'Deny'
    dnsSettings: {
      enableProxy: true
    }
    intrusionDetection: skuTier == 'Premium'
      ? {
          mode: 'Deny'
        }
      : null
  }
}

resource platformRules 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = {
  parent: firewallPolicy
  name: 'rcg-platform'
  properties: {
    priority: 200
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'allow-core-azure'
        priority: 200
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'azure-monitor'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: spokeAddressSpace
            destinationAddresses: [
              'AzureMonitor'
            ]
            destinationPorts: [
              '443'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'azure-kms-activation'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: spokeAddressSpace
            destinationFqdns: [
              'kms.core.windows.net'
              'azkms.core.windows.net'
            ]
            destinationPorts: [
              '1688'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'ntp'
            ipProtocols: [
              'UDP'
            ]
            sourceAddresses: spokeAddressSpace
            destinationFqdns: [
              'time.windows.com'
            ]
            destinationPorts: [
              '123'
            ]
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'allow-platform-fqdns'
        priority: 300
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'windows-update'
            sourceAddresses: spokeAddressSpace
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
              {
                protocolType: 'Http'
                port: 80
              }
            ]
            fqdnTags: [
              'WindowsUpdate'
              'WindowsDiagnostics'
              'MicrosoftActiveProtectionService'
            ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'azure-services'
            sourceAddresses: spokeAddressSpace
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            targetFqdns: [
              '*.azure.com'
              '*.microsoft.com'
              '*.microsoftonline.com'
              '*.windows.net'
              '*.azure-automation.net'
            ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'linux-package-repos'
            sourceAddresses: spokeAddressSpace
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
              {
                protocolType: 'Http'
                port: 80
              }
            ]
            targetFqdns: [
              '*.ubuntu.com'
              'azure.archive.ubuntu.com'
              'packages.microsoft.com'
            ]
          }
        ]
      }
    ]
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2024-05-01' = {
  name: name
  location: location
  tags: tags
  zones: zones
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: skuTier
    }
    firewallPolicy: {
      id: firewallPolicy.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: subnetId
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
  dependsOn: [
    platformRules
  ]
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${name}'
  scope: firewall
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logAnalyticsDestinationType: 'Dedicated'
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

output firewallId string = firewall.id
output privateIpAddress string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output publicIpAddress string = publicIp.properties.ipAddress
output policyId string = firewallPolicy.id
