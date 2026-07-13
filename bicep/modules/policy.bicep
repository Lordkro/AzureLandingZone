targetScope = 'subscription'

@description('Baseline Azure Policy assignments for the landing zone.')
param location string
param allowedLocations array
param requiredTags array

var builtin = {
  allowedLocations: tenantResourceId('Microsoft.Authorization/policyDefinitions', 'e56962a6-4747-49cd-b67b-bf8b01975c4c')
  requireTagOnRg: tenantResourceId('Microsoft.Authorization/policyDefinitions', '96670d01-0a4d-4649-9c89-2d3abc0a5025')
  inheritTagFromRg: tenantResourceId('Microsoft.Authorization/policyDefinitions', 'cd3aa116-8754-49c9-a813-ad46512ece54')
  storageHttpsOnly: tenantResourceId('Microsoft.Authorization/policyDefinitions', '404c3081-a854-4457-ae30-26a93ef643f9')
  auditUnmanagedDisks: tenantResourceId('Microsoft.Authorization/policyDefinitions', '06a78e20-9358-41c9-923c-fb736d382a4d')
  kvPurgeProtection: tenantResourceId('Microsoft.Authorization/policyDefinitions', '0b60c0b2-2dc2-4e1c-b5c9-abbed971de53')
  periodicUpdateChecks: tenantResourceId('Microsoft.Authorization/policyDefinitions', '59efceea-0c96-497e-a4a1-4eb2290dac15')
}

var contributorRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
var vmContributorRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '9980e02c-c2be-4d73-94e8-173b1dc7cf3c')

resource allowedLocationsAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'allowed-locations'
  properties: {
    displayName: 'Allowed locations'
    policyDefinitionId: builtin.allowedLocations
    parameters: {
      listOfAllowedLocations: {
        value: allowedLocations
      }
    }
  }
}

resource requireTagAssignments 'Microsoft.Authorization/policyAssignments@2024-04-01' = [
  for tag in requiredTags: {
    name: 'require-tag-${tag}'
    properties: {
      displayName: 'Require \'${tag}\' tag on resource groups'
      policyDefinitionId: builtin.requireTagOnRg
      parameters: {
        tagName: {
          value: tag
        }
      }
    }
  }
]

resource inheritTagAssignments 'Microsoft.Authorization/policyAssignments@2024-04-01' = [
  for tag in requiredTags: {
    name: 'inherit-tag-${tag}'
    location: location
    identity: {
      type: 'SystemAssigned'
    }
    properties: {
      displayName: 'Inherit \'${tag}\' tag from resource group'
      policyDefinitionId: builtin.inheritTagFromRg
      parameters: {
        tagName: {
          value: tag
        }
      }
    }
  }
]

resource inheritTagRemediation 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for (tag, i) in requiredTags: {
    name: guid(subscription().id, 'inherit-tag-${tag}', contributorRole)
    properties: {
      principalId: inheritTagAssignments[i].identity.principalId
      roleDefinitionId: contributorRole
      principalType: 'ServicePrincipal'
    }
  }
]

resource storageHttpsAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'storage-https-only'
  properties: {
    displayName: 'Secure transfer to storage accounts should be enabled'
    policyDefinitionId: builtin.storageHttpsOnly
  }
}

resource unmanagedDisksAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'audit-unmanaged-disks'
  properties: {
    displayName: 'Audit VMs that do not use managed disks'
    policyDefinitionId: builtin.auditUnmanagedDisks
  }
}

resource kvPurgeAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'kv-purge-protection'
  properties: {
    displayName: 'Key vaults should have purge protection enabled'
    policyDefinitionId: builtin.kvPurgeProtection
  }
}

resource periodicUpdateAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'periodic-update-checks'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'Configure periodic checking for missing system updates'
    policyDefinitionId: builtin.periodicUpdateChecks
  }
}

resource periodicUpdateRemediation 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, 'periodic-update-checks', vmContributorRole)
  properties: {
    principalId: periodicUpdateAssignment.identity.principalId
    roleDefinitionId: vmContributorRole
    principalType: 'ServicePrincipal'
  }
}
