targetScope = 'subscription'

// ---------------------------------------------------------------------------
// Custom role definitions for platform separation of duties.
//
// The built-in Owner/Contributor pair is too coarse for a landing zone: network
// and security teams need write access to their own resource providers without
// the ability to grant themselves more, and workload teams must not be able to
// rewrite platform routing. Modelled on the CAF enterprise-scale reference set —
// treat as a starting point and tighten per organisation.
// ---------------------------------------------------------------------------

@description('Scopes the roles may be assigned at. Defaults to this subscription.')
param assignableScopes array = []

@description('Which roles to create: platformOwner, networkManagement, securityOperations, subscriptionOwner, applicationOwner.')
param enabledRoles array = [
  'platformOwner'
  'networkManagement'
  'securityOperations'
  'subscriptionOwner'
  'applicationOwner'
]

var scopes = empty(assignableScopes) ? [subscription().id] : assignableScopes

var roleCatalogue = {
  platformOwner: {
    roleName: 'Azure Platform Owner'
    description: 'Full management of the platform hierarchy, including policy and role assignments. Intended for PIM-eligible platform leads only.'
    actions: [
      '*'
    ]
    notActions: []
    dataActions: []
    notDataActions: []
  }
  networkManagement: {
    roleName: 'Network Management (NetOps)'
    description: 'Manage all networking resources — hub, spokes, firewall policy, routing, DNS — without access to other resource providers.'
    actions: [
      '*/read'
      'Microsoft.Network/*'
      'Microsoft.Resources/deployments/*'
      'Microsoft.Resources/subscriptions/resourceGroups/read'
      'Microsoft.Insights/alertRules/*'
      'Microsoft.Insights/diagnosticSettings/*'
      'Microsoft.Support/*'
    ]
    notActions: []
    dataActions: []
    notDataActions: []
  }
  securityOperations: {
    roleName: 'Security Operations (SecOps)'
    description: 'Manage Defender for Cloud, Sentinel, diagnostics and alerting across the estate. Read-only on everything else.'
    actions: [
      '*/read'
      'Microsoft.AlertsManagement/alerts/*'
      'Microsoft.AlertsManagement/alertsSummary/*'
      'Microsoft.Insights/alertRules/*'
      'Microsoft.Insights/diagnosticSettings/*'
      'Microsoft.Insights/eventtypes/*'
      'Microsoft.Insights/scheduledQueryRules/*'
      'Microsoft.OperationalInsights/*'
      'Microsoft.Resources/deployments/*'
      'Microsoft.Security/*'
      'Microsoft.SecurityInsights/*'
      'Microsoft.Support/*'
    ]
    notActions: []
    dataActions: []
    notDataActions: []
  }
  subscriptionOwner: {
    roleName: 'Subscription Owner'
    description: 'Owner of a landing zone subscription, minus the ability to change platform connectivity or grant roles.'
    actions: [
      '*'
    ]
    notActions: [
      'Microsoft.Authorization/*/write'
      'Microsoft.Network/vpnGateways/*'
      'Microsoft.Network/expressRouteCircuits/*'
      'Microsoft.Network/routeTables/write'
      'Microsoft.Network/vpnSites/*'
      'Microsoft.Network/virtualNetworks/peer/action'
    ]
    dataActions: []
    notDataActions: []
  }
  applicationOwner: {
    roleName: 'Application Owner (DevOps)'
    description: 'Deploy and operate workloads inside a landing zone. Cannot change networking, policy or role assignments.'
    actions: [
      '*/read'
      'Microsoft.AlertsManagement/*'
      'Microsoft.Authorization/locks/*'
      'Microsoft.Insights/*'
      'Microsoft.OperationalInsights/workspaces/*'
      'Microsoft.Resources/deployments/*'
      'Microsoft.Resources/tags/*'
      'Microsoft.Support/*'
      'Microsoft.Compute/*'
      'Microsoft.Web/*'
      'Microsoft.ContainerService/*'
      'Microsoft.KeyVault/vaults/read'
      'Microsoft.Storage/storageAccounts/*'
    ]
    notActions: [
      'Microsoft.Authorization/roleAssignments/write'
      'Microsoft.Authorization/roleDefinitions/write'
      'Microsoft.Authorization/policyAssignments/write'
      'Microsoft.Network/routeTables/write'
      'Microsoft.Network/virtualNetworks/write'
      'Microsoft.Network/virtualNetworks/peer/action'
    ]
    dataActions: []
    notDataActions: []
  }
}

resource roles 'Microsoft.Authorization/roleDefinitions@2022-04-01' = [
  for key in enabledRoles: {
    // Deterministic GUID so redeploying never recreates the definition (which
    // would orphan every assignment referencing it).
    name: guid(subscription().id, roleCatalogue[key].roleName)
    properties: {
      roleName: roleCatalogue[key].roleName
      description: roleCatalogue[key].description
      type: 'CustomRole'
      permissions: [
        {
          actions: roleCatalogue[key].actions
          notActions: roleCatalogue[key].notActions
          dataActions: roleCatalogue[key].dataActions
          notDataActions: roleCatalogue[key].notDataActions
        }
      ]
      assignableScopes: scopes
    }
  }
]

output roleDefinitionIds array = [
  for (key, i) in enabledRoles: {
    key: key
    roleName: roleCatalogue[key].roleName
    id: roles[i].id
  }
]
