targetScope = 'subscription'

@description('Baseline Azure Policy assignments for the landing zone.')
param location string
param allowedLocations array
param requiredTags array

@description('Resource types blocked outright, e.g. ["Microsoft.ClassicCompute/virtualMachines"]. Empty skips the assignment.')
param deniedResourceTypes array = []

@description('Deny public IPs on NICs — they bypass the hub firewall and the forced-tunnelling route table.')
param denyPublicIpOnNic bool = true

@description('Effect for the storage public-network-access assignment. Start at Audit, move to Deny once workloads comply.')
@allowed([
  'Audit'
  'Deny'
  'Disabled'
])
param storagePublicAccessEffect string = 'Audit'

@description('Assign the policies that install Azure Monitor Agent and bind VMs to the platform data collection rule.')
param deployAzureMonitorAgent bool = true

@description('Resource ID of the platform data collection rule. Empty skips the DCR association policies.')
param dataCollectionRuleId string = ''

// Built-in policy definition IDs. Verify with:
//   az policy definition show --name <guid> --query displayName
var builtin = {
  allowedLocations: tenantResourceId('Microsoft.Authorization/policyDefinitions', 'e56962a6-4747-49cd-b67b-bf8b01975c4c')
  requireTagOnRg: tenantResourceId('Microsoft.Authorization/policyDefinitions', '96670d01-0a4d-4649-9c89-2d3abc0a5025')
  inheritTagFromRg: tenantResourceId('Microsoft.Authorization/policyDefinitions', 'cd3aa116-8754-49c9-a813-ad46512ece54')
  storageHttpsOnly: tenantResourceId('Microsoft.Authorization/policyDefinitions', '404c3081-a854-4457-ae30-26a93ef643f9')
  storageNoPublicNetwork: tenantResourceId(
    'Microsoft.Authorization/policyDefinitions',
    'b2982f36-99f2-4db5-8eff-283140c09693'
  )
  auditUnmanagedDisks: tenantResourceId('Microsoft.Authorization/policyDefinitions', '06a78e20-9358-41c9-923c-fb736d382a4d')
  kvPurgeProtection: tenantResourceId('Microsoft.Authorization/policyDefinitions', '0b60c0b2-2dc2-4e1c-b5c9-abbed971de53')
  kvFirewallEnabled: tenantResourceId('Microsoft.Authorization/policyDefinitions', '55615ac9-af46-4a59-874e-391cc3dfb490')
  periodicUpdateChecks: tenantResourceId(
    'Microsoft.Authorization/policyDefinitions',
    '59efceea-0c96-497e-a4a1-4eb2290dac15'
  )
  nicNoPublicIp: tenantResourceId('Microsoft.Authorization/policyDefinitions', '83a86a26-fd1f-447c-b59d-e51f44264114')
  securityContactEmail: tenantResourceId(
    'Microsoft.Authorization/policyDefinitions',
    '4f4f78b8-e367-4b10-a341-d9a4ad5cf1c7'
  )
  notAllowedTypes: tenantResourceId('Microsoft.Authorization/policyDefinitions', '6c112d4e-5bc7-47ae-a041-ea2d9dccd749')
  amaWindowsVm: tenantResourceId('Microsoft.Authorization/policyDefinitions', 'ca817e41-e85a-4783-bc7f-dc532d36235e')
  amaLinuxVm: tenantResourceId('Microsoft.Authorization/policyDefinitions', 'a4034bc6-ae50-406d-bf76-50f4ee5a7811')
  dcrAssociationWindows: tenantResourceId(
    'Microsoft.Authorization/policyDefinitions',
    '244efd75-0d92-453c-b9a3-7d73ca36ed52'
  )
  dcrAssociationLinux: tenantResourceId(
    'Microsoft.Authorization/policyDefinitions',
    '58e891b9-ce13-4ac3-86e4-ac3e1f20cb07'
  )
}

var contributorRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
var vmContributorRole = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '9980e02c-c2be-4d73-94e8-173b1dc7cf3c'
)
var monitoringContributorRole = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '749f88d5-cbae-40b8-bcfc-e573ddc772fa'
)
var logAnalyticsContributorRole = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '92aaf0da-9dab-42b6-94a3-d43ce8d16293'
)

// ---------------------------------------------------------------------------
// Governance: locations and tagging
// ---------------------------------------------------------------------------

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

// Blocks whole resource providers the organisation has not approved
// (e.g. Microsoft.ClassicCompute).
resource notAllowedTypesAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = if (!empty(deniedResourceTypes)) {
  name: 'not-allowed-resource-types'
  properties: {
    displayName: 'Not allowed resource types'
    policyDefinitionId: builtin.notAllowedTypes
    parameters: {
      listOfResourceTypesNotAllowed: {
        value: deniedResourceTypes
      }
      effect: {
        value: 'Deny'
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Data protection
// ---------------------------------------------------------------------------

resource storageHttpsAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'storage-https-only'
  properties: {
    displayName: 'Secure transfer to storage accounts should be enabled'
    policyDefinitionId: builtin.storageHttpsOnly
    parameters: {
      effect: {
        value: 'Deny'
      }
    }
  }
}

// The landing zone's own storage disables public network access; this stops
// workload teams from creating accounts that do not.
resource storageNoPublicNetworkAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'storage-no-public-network'
  properties: {
    displayName: 'Storage accounts should disable public network access'
    policyDefinitionId: builtin.storageNoPublicNetwork
    parameters: {
      effect: {
        value: storagePublicAccessEffect
      }
    }
  }
}

resource kvPurgeAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'kv-purge-protection'
  properties: {
    displayName: 'Key vaults should have purge protection enabled'
    policyDefinitionId: builtin.kvPurgeProtection
    parameters: {
      effect: {
        value: 'Audit'
      }
    }
  }
}

resource kvFirewallAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'kv-firewall-enabled'
  properties: {
    displayName: 'Key vaults should have firewall enabled or public network access disabled'
    policyDefinitionId: builtin.kvFirewallEnabled
    parameters: {
      effect: {
        value: 'Audit'
      }
    }
  }
}

resource unmanagedDisksAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'audit-unmanaged-disks'
  properties: {
    displayName: 'Audit VMs that do not use managed disks'
    policyDefinitionId: builtin.auditUnmanagedDisks
  }
}

// ---------------------------------------------------------------------------
// Network isolation
// ---------------------------------------------------------------------------

resource nicNoPublicIpAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = if (denyPublicIpOnNic) {
  name: 'nic-no-public-ip'
  properties: {
    displayName: 'Network interfaces should not have public IPs'
    description: 'Public IPs on NICs bypass the hub firewall and the forced-tunnelling route table.'
    policyDefinitionId: builtin.nicNoPublicIp
  }
}

// ---------------------------------------------------------------------------
// Security posture
// ---------------------------------------------------------------------------

resource securityContactAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'security-contact-email'
  properties: {
    displayName: 'Subscriptions should have a contact email address for security issues'
    policyDefinitionId: builtin.securityContactEmail
  }
}

// ---------------------------------------------------------------------------
// Update Manager: enable periodic assessment on all VMs (modify effect).
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Azure Monitor Agent: install it, then bind it to the platform DCR.
//
// Without these two pairs the data collection rule created by the logAnalytics
// module collects nothing — VMs would need the agent installed and associated by
// hand. This is what turns the DCR into an actual monitoring baseline.
// ---------------------------------------------------------------------------

var amaAssignments = deployAzureMonitorAgent
  ? [
      {
        name: 'ama-windows'
        displayName: 'Configure Windows virtual machines to run Azure Monitor Agent'
        definitionId: builtin.amaWindowsVm
      }
      {
        name: 'ama-linux'
        displayName: 'Configure Linux virtual machines to run Azure Monitor Agent'
        definitionId: builtin.amaLinuxVm
      }
    ]
  : []

var dcrAssignments = deployAzureMonitorAgent && !empty(dataCollectionRuleId)
  ? [
      {
        name: 'dcr-windows'
        displayName: 'Associate Windows VMs with the platform data collection rule'
        definitionId: builtin.dcrAssociationWindows
      }
      {
        name: 'dcr-linux'
        displayName: 'Associate Linux VMs with the platform data collection rule'
        definitionId: builtin.dcrAssociationLinux
      }
    ]
  : []

resource amaPolicyAssignments 'Microsoft.Authorization/policyAssignments@2024-04-01' = [
  for assignment in amaAssignments: {
    name: assignment.name
    location: location
    identity: {
      type: 'SystemAssigned'
    }
    properties: {
      displayName: assignment.displayName
      policyDefinitionId: assignment.definitionId
    }
  }
]

resource amaRemediation 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for (assignment, i) in amaAssignments: {
    name: guid(subscription().id, assignment.name, vmContributorRole)
    properties: {
      principalId: amaPolicyAssignments[i].identity.principalId
      roleDefinitionId: vmContributorRole
      principalType: 'ServicePrincipal'
    }
  }
]

resource dcrPolicyAssignments 'Microsoft.Authorization/policyAssignments@2024-04-01' = [
  for assignment in dcrAssignments: {
    name: assignment.name
    location: location
    identity: {
      type: 'SystemAssigned'
    }
    properties: {
      displayName: assignment.displayName
      policyDefinitionId: assignment.definitionId
      parameters: {
        dcrResourceId: {
          value: dataCollectionRuleId
        }
        resourceType: {
          value: 'Microsoft.Insights/dataCollectionRules'
        }
      }
    }
  }
]

// The DCR association policy needs to read the rule and write the association.
resource dcrMonitoringRemediation 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for (assignment, i) in dcrAssignments: {
    name: guid(subscription().id, assignment.name, monitoringContributorRole)
    properties: {
      principalId: dcrPolicyAssignments[i].identity.principalId
      roleDefinitionId: monitoringContributorRole
      principalType: 'ServicePrincipal'
    }
  }
]

resource dcrLogAnalyticsRemediation 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for (assignment, i) in dcrAssignments: {
    name: guid(subscription().id, assignment.name, logAnalyticsContributorRole)
    properties: {
      principalId: dcrPolicyAssignments[i].identity.principalId
      roleDefinitionId: logAnalyticsContributorRole
      principalType: 'ServicePrincipal'
    }
  }
]
