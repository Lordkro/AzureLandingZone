targetScope = 'tenant'

// ---------------------------------------------------------------------------
// CAF management group hierarchy.
//
//   Tenant Root Group
//   └── mg-<prefix>                (intermediate root)
//       ├── mg-<prefix>-platform
//       │   ├── mg-<prefix>-identity
//       │   ├── mg-<prefix>-management
//       │   └── mg-<prefix>-connectivity
//       ├── mg-<prefix>-landingzones
//       │   ├── mg-<prefix>-corp    (private / on-prem connected workloads)
//       │   └── mg-<prefix>-online  (internet-facing workloads)
//       ├── mg-<prefix>-sandbox     (loose policy, no connectivity)
//       └── mg-<prefix>-decommissioned
//
// This is a SEPARATE deployment from main.bicep: management groups are tenant
// scoped, main.bicep is subscription scoped, and a single template cannot span
// both. Deploy it first, then main.bicep. Requires Owner or Management Group
// Contributor on the Tenant Root Group:
//
//   az deployment tenant create \
//     --name alz-management-groups \
//     --location westeurope \
//     --template-file bicep/managementGroups.bicep \
//     --parameters prefix=contoso displayName=Contoso
// ---------------------------------------------------------------------------

@description('Prefix for management group names.')
@minLength(2)
@maxLength(8)
param prefix string

@description('Display name of the intermediate root management group.')
param displayName string = 'Landing Zone'

@description('Parent management group name for the intermediate root. Empty anchors it at the Tenant Root Group.')
param parentManagementGroupName string = ''

@description('Map of subscription GUID => hierarchy key. Valid keys: intermediateRoot, platform, identity, management, connectivity, landingZones, corp, online, sandbox, decommissioned.')
param subscriptionPlacements object = {}

var parentId = empty(parentManagementGroupName)
  ? tenantResourceId('Microsoft.Management/managementGroups', tenant().tenantId)
  : tenantResourceId('Microsoft.Management/managementGroups', parentManagementGroupName)

resource intermediateRoot 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: 'mg-${prefix}'
  scope: tenant()
  properties: {
    displayName: displayName
    details: {
      parent: {
        id: parentId
      }
    }
  }
}

resource platform 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: 'mg-${prefix}-platform'
  scope: tenant()
  properties: {
    displayName: 'Platform'
    details: {
      parent: {
        id: intermediateRoot.id
      }
    }
  }
}

var platformChildren = [
  {
    key: 'identity'
    displayName: 'Identity'
  }
  {
    key: 'management'
    displayName: 'Management'
  }
  {
    key: 'connectivity'
    displayName: 'Connectivity'
  }
]

@batchSize(1)
resource platformChildGroups 'Microsoft.Management/managementGroups@2023-04-01' = [
  for child in platformChildren: {
    name: 'mg-${prefix}-${child.key}'
    scope: tenant()
    properties: {
      displayName: child.displayName
      details: {
        parent: {
          id: platform.id
        }
      }
    }
  }
]

resource landingZones 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: 'mg-${prefix}-landingzones'
  scope: tenant()
  properties: {
    displayName: 'Landing Zones'
    details: {
      parent: {
        id: intermediateRoot.id
      }
    }
  }
}

var landingZoneChildren = [
  {
    key: 'corp'
    displayName: 'Corp'
  }
  {
    key: 'online'
    displayName: 'Online'
  }
]

@batchSize(1)
resource landingZoneChildGroups 'Microsoft.Management/managementGroups@2023-04-01' = [
  for child in landingZoneChildren: {
    name: 'mg-${prefix}-${child.key}'
    scope: tenant()
    properties: {
      displayName: child.displayName
      details: {
        parent: {
          id: landingZones.id
        }
      }
    }
  }
]

resource sandbox 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: 'mg-${prefix}-sandbox'
  scope: tenant()
  properties: {
    displayName: 'Sandbox'
    details: {
      parent: {
        id: intermediateRoot.id
      }
    }
  }
}

resource decommissioned 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: 'mg-${prefix}-decommissioned'
  scope: tenant()
  properties: {
    displayName: 'Decommissioned'
    details: {
      parent: {
        id: intermediateRoot.id
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Subscription placement
// ---------------------------------------------------------------------------

var groupNames = {
  intermediateRoot: 'mg-${prefix}'
  platform: 'mg-${prefix}-platform'
  identity: 'mg-${prefix}-identity'
  management: 'mg-${prefix}-management'
  connectivity: 'mg-${prefix}-connectivity'
  landingZones: 'mg-${prefix}-landingzones'
  corp: 'mg-${prefix}-corp'
  online: 'mg-${prefix}-online'
  sandbox: 'mg-${prefix}-sandbox'
  decommissioned: 'mg-${prefix}-decommissioned'
}

var placementSubscriptionIds = objectKeys(subscriptionPlacements)

@batchSize(1)
resource placements 'Microsoft.Management/managementGroups/subscriptions@2021-04-01' = [
  for subId in placementSubscriptionIds: {
    name: '${groupNames[subscriptionPlacements[subId]]}/${subId}'
    scope: tenant()
  }
]

output intermediateRootId string = intermediateRoot.id
output platformId string = platform.id
output landingZonesId string = landingZones.id
output managementGroupNames object = groupNames
