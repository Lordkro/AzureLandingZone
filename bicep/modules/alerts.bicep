// ---------------------------------------------------------------------------
// Platform action group plus the alert rules that catch the failures a hub-spoke
// landing zone actually suffers: Azure-side outages, degraded platform
// resources, firewall SNAT exhaustion and dead App Gateway backends.
// ---------------------------------------------------------------------------

@description('Naming suffix (<prefix>-<environment>-<region>).')
param suffix string

@description('Action group short name, max 12 characters — shown as the SMS/email sender.')
@maxLength(12)
param actionGroupShortName string

@description('Email addresses that receive platform alerts.')
param notificationEmails array = []

@description('Webhook URIs (Teams, PagerDuty, ...) that receive platform alerts.')
param notificationWebhooks array = []

@description('Regions to watch for service health events.')
param serviceHealthLocations array

param firewallId string

@description('Application Gateway resource ID. Empty string disables its metric alert.')
param appGatewayId string = ''

param tags object = {}

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-platform-${suffix}'
  location: 'global'
  tags: tags
  properties: {
    groupShortName: actionGroupShortName
    enabled: true
    emailReceivers: [
      for (email, i) in notificationEmails: {
        name: 'email-${i}'
        emailAddress: email
        useCommonAlertSchema: true
      }
    ]
    webhookReceivers: [
      for (uri, i) in notificationWebhooks: {
        name: 'webhook-${i}'
        serviceUri: uri
        useCommonAlertSchema: true
      }
    ]
  }
}

resource serviceHealthAlert 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: 'alert-service-health-${suffix}'
  location: 'global'
  tags: tags
  properties: {
    enabled: true
    description: 'Azure service issues, planned maintenance and security advisories affecting this subscription.'
    scopes: [
      subscription().id
    ]
    condition: {
      allOf: [
        {
          field: 'category'
          equals: 'ServiceHealth'
        }
        {
          anyOf: [
            {
              field: 'properties.incidentType'
              equals: 'Incident'
            }
            {
              field: 'properties.incidentType'
              equals: 'Maintenance'
            }
            {
              field: 'properties.incidentType'
              equals: 'Security'
            }
          ]
        }
        {
          field: 'properties.impactedServices[*].ImpactedRegions[*].RegionName'
          containsAny: serviceHealthLocations
        }
      ]
    }
    actions: {
      actionGroups: [
        {
          actionGroupId: actionGroup.id
        }
      ]
    }
  }
}

resource resourceHealthAlert 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: 'alert-resource-health-${suffix}'
  location: 'global'
  tags: tags
  properties: {
    enabled: true
    description: 'Platform resources reporting Degraded or Unavailable health.'
    scopes: [
      subscription().id
    ]
    condition: {
      allOf: [
        {
          field: 'category'
          equals: 'ResourceHealth'
        }
        {
          anyOf: [
            {
              field: 'properties.currentHealthStatus'
              equals: 'Degraded'
            }
            {
              field: 'properties.currentHealthStatus'
              equals: 'Unavailable'
            }
          ]
        }
        // Only platform-initiated changes; a user stopping a VM is expected and
        // would otherwise be constant noise.
        {
          field: 'properties.cause'
          equals: 'PlatformInitiated'
        }
      ]
    }
    actions: {
      actionGroups: [
        {
          actionGroupId: actionGroup.id
        }
      ]
    }
  }
}

resource governanceAlert 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: 'alert-governance-changes-${suffix}'
  location: 'global'
  tags: tags
  properties: {
    enabled: true
    description: 'Role assignment created or deleted at subscription scope.'
    scopes: [
      subscription().id
    ]
    condition: {
      allOf: [
        {
          field: 'category'
          equals: 'Administrative'
        }
        {
          field: 'operationName'
          equals: 'Microsoft.Authorization/roleAssignments/write'
        }
      ]
    }
    actions: {
      actionGroups: [
        {
          actionGroupId: actionGroup.id
        }
      ]
    }
  }
}

resource firewallHealthAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-firewall-health-${suffix}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Azure Firewall health state degraded.'
    severity: 1
    enabled: true
    scopes: [
      firewallId
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'FirewallHealth'
          metricNamespace: 'Microsoft.Network/azureFirewalls'
          metricName: 'FirewallHealth'
          operator: 'LessThan'
          threshold: 100
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

// SNAT exhaustion silently drops outbound connections — the classic hub failure.
resource firewallSnatAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-firewall-snat-${suffix}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Azure Firewall SNAT port utilisation above 95% — add public IPs.'
    severity: 1
    enabled: true
    scopes: [
      firewallId
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'SNATPortUtilization'
          metricNamespace: 'Microsoft.Network/azureFirewalls'
          metricName: 'SNATPortUtilization'
          operator: 'GreaterThan'
          threshold: 95
          timeAggregation: 'Maximum'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

resource appGatewayUnhealthyHostsAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = if (!empty(appGatewayId)) {
  name: 'alert-appgw-unhealthy-hosts-${suffix}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Application Gateway backend hosts failing health probes.'
    severity: 2
    enabled: true
    scopes: [
      appGatewayId
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'UnhealthyHostCount'
          metricNamespace: 'Microsoft.Network/applicationGateways'
          metricName: 'UnhealthyHostCount'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

output actionGroupId string = actionGroup.id
