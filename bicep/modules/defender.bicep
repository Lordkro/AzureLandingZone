targetScope = 'subscription'

@description('Microsoft Defender for Cloud plans, security contact and workspace routing.')
param plans array
param securityContactEmail string
param logAnalyticsWorkspaceId string

@batchSize(1)
resource pricings 'Microsoft.Security/pricings@2024-01-01' = [
  for plan in plans: {
    name: plan
    properties: {
      pricingTier: 'Standard'
    }
  }
]

resource securityContact 'Microsoft.Security/securityContacts@2023-12-01-preview' = {
  name: 'default'
  properties: {
    emails: securityContactEmail
    isEnabled: true
    notificationsByRole: {
      state: 'On'
      roles: [
        'Owner'
      ]
    }
    notificationsSources: [
      {
        sourceType: 'Alert'
        minimalSeverity: 'High'
      }
    ]
  }
}

resource workspaceSetting 'Microsoft.Security/workspaceSettings@2017-08-01-preview' = {
  name: 'default'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    scope: subscription().id
  }
}
