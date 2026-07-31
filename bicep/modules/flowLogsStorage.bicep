// Dedicated storage for VNet flow logs. They are high-volume and write-heavy,
// and mixing them with application data makes lifecycle rules and access
// control awkward.
param name string
param location string

@description('Days to keep raw flow log blobs before the lifecycle rule deletes them.')
param retentionDays int = 30

@description('Public IPs allowed to read flow log blobs directly (e.g. an analyst workstation egress IP).')
param allowedIpRules array = []

param tags object = {}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Enabled'
    // The flow log writer authenticates with the account key, so shared-key
    // access cannot be disabled here (unlike the workload storage account).
    // Access is instead constrained by the network rules below.
    allowSharedKeyAccess: true
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices, Logging, Metrics'
      ipRules: [
        for ip in allowedIpRules: {
          value: ip
          action: 'Allow'
        }
      ]
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// Flow log blobs are only useful while an investigation is open; Traffic
// Analytics keeps the aggregated view in the workspace.
resource lifecycle 'Microsoft.Storage/storageAccounts/managementPolicies@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    policy: {
      rules: [
        {
          name: 'expire-flow-logs'
          enabled: true
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: [
                'blockBlob'
              ]
              prefixMatch: [
                'insights-logs-flowlogflowevent'
              ]
            }
            actions: {
              baseBlob: {
                delete: {
                  daysAfterModificationGreaterThan: retentionDays
                }
              }
            }
          }
        }
      ]
    }
  }
  dependsOn: [
    blobService
  ]
}

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
