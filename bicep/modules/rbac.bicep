targetScope = 'subscription'

@description('Subscription-scope role assignments. Each item: { principalId, roleDefinitionId (GUID), principalType }.')
param assignments array = []

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for assignment in assignments: {
    name: guid(subscription().id, assignment.principalId, assignment.roleDefinitionId)
    properties: {
      principalId: assignment.principalId
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', assignment.roleDefinitionId)
      principalType: assignment.?principalType ?? 'Group'
    }
  }
]
