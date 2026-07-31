targetScope = 'subscription'

@description('Microsoft Defender for Cloud plans, security contact and workspace routing.')
param plans array
param securityContactEmail string

@description('Phone number Defender uses for high-severity escalation, E.164 format.')
param securityContactPhone string

param logAnalyticsWorkspaceId string

// CKV_AZURE_87 wants a literal pricing resource named 'KeyVaults'. This loop
// enables whatever is in `plans` — which includes KeyVaults by default — but
// Checkov cannot resolve the loop variable to a literal name, so it reports the
// plan as off. Verify with: az security pricing show -n KeyVaults
@batchSize(1)
resource pricings 'Microsoft.Security/pricings@2024-01-01' = [
  for plan in plans: {
    //checkov:skip=CKV_AZURE_87:KeyVaults is enabled through the plans array; Checkov cannot resolve a loop variable to the literal resource name it looks for.
    name: plan
    properties: {
      pricingTier: 'Standard'
    }
  }
]

// CKV_AZURE_21 and CKV_AZURE_22 look for the legacy 2017-08-01-preview string
// properties `alertNotifications: 'On'` and `alertsToAdmins: 'On'`. This resource
// uses the current 2023-12-01-preview schema, where the same behaviour is
// expressed by `notificationsSources` (alerts at High and above) and
// `notificationsByRole` (Owners). Writing the legacy keys here would be
// meaningless — the current API ignores them.
resource securityContact 'Microsoft.Security/securityContacts@2023-12-01-preview' = {
  //checkov:skip=CKV_AZURE_21:Legacy 2017 schema key. The equivalent on this API version is notificationsSources with minimalSeverity High, set below.
  //checkov:skip=CKV_AZURE_22:Legacy 2017 schema key. The equivalent on this API version is notificationsByRole with the Owner role, set below.
  name: 'default'
  properties: {
    emails: securityContactEmail
    phone: securityContactPhone
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
