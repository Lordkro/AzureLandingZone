@description('Application Gateway WAF_v2 with autoscaling and an OWASP 3.2 WAF policy in Prevention mode.')
param name string
param location string
param subnetId string
param autoscaleMin int = 1
param autoscaleMax int = 3
param zones array = [
  '1'
  '2'
  '3'
]
@description('Predefined SSL policy. AppGwSslPolicy20220101S is the strict profile: TLS 1.2 floor, strong cipher suites only.')
@allowed([
  'AppGwSslPolicy20220101S'
  'AppGwSslPolicy20220101'
  'AppGwSslPolicy20170401S'
])
param sslPolicyName string = 'AppGwSslPolicy20220101S'

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

resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2024-05-01' = {
  name: 'waf-${name}'
  location: location
  tags: tags
  properties: {
    policySettings: {
      state: 'Enabled'
      mode: 'Prevention'
      requestBodyCheck: true
      fileUploadLimitInMb: 100
      maxRequestBodySizeInKb: 128
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '1.0'
        }
      ]
    }
  }
}

resource appGateway 'Microsoft.Network/applicationGateways@2024-05-01' = {
  name: name
  location: location
  tags: tags
  zones: zones
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    // TLS 1.2 floor with only the strong cipher suites. AppGwSslPolicy20220101S
    // is the "strict" predefined policy — it drops TLS 1.0/1.1 and the CBC and
    // 3DES suites the default policy still permits.
    sslPolicy: {
      policyType: 'Predefined'
      policyName: sslPolicyName
    }
    autoscaleConfiguration: {
      minCapacity: autoscaleMin
      maxCapacity: autoscaleMax
    }
    firewallPolicy: {
      id: wafPolicy.id
    }
    gatewayIPConfigurations: [
      {
        name: 'gateway-ip'
        properties: {
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'frontend-public'
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port-80'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'backend-default'
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'http-settings-default'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
        }
      }
    ]
    httpListeners: [
      {
        name: 'listener-http'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', name, 'frontend-public')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', name, 'port-80')
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'rule-default'
        properties: {
          priority: 100
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', name, 'listener-http')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', name, 'backend-default')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', name, 'http-settings-default')
          }
        }
      }
    ]
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${name}'
  scope: appGateway
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

output appGatewayId string = appGateway.id
output publicIpAddress string = publicIp.properties.ipAddress
output wafPolicyId string = wafPolicy.id
