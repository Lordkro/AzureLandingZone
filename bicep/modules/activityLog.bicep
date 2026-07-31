targetScope = 'subscription'

// The subscription activity log is the audit trail for every control-plane
// operation. Without this setting it is only retained for 90 days and cannot be
// queried alongside resource logs. Subscription diagnostic settings carry logs
// only — there are no metrics at this scope.
@description('Route the subscription activity log to the central workspace.')
param logAnalyticsWorkspaceId string

var categories = [
  'Administrative'
  'Security'
  'ServiceHealth'
  'Alert'
  'Recommendation'
  'Policy'
  'Autoscale'
  'ResourceHealth'
]

resource activityLog 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-activity-log'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      for category in categories: {
        category: category
        enabled: true
      }
    ]
  }
}

output diagnosticSettingId string = activityLog.id
