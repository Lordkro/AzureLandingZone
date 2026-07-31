// Dedicated storage for VNet flow logs. They are high-volume and write-heavy,
// and mixing them with application data makes lifecycle rules and access
// control awkward.
param name string
param location string

@description('Days to keep raw flow log blobs before the lifecycle rule deletes them.')
param retentionDays int = 90

@description('Replication. ZRS keeps the evidence available through a zone outage.')
@allowed([
  'Standard_ZRS'
  'Standard_GRS'
  'Standard_GZRS'
  'Standard_RAGRS'
  'Standard_LRS'
])
param replicationType string = 'Standard_ZRS'

@description('Maximum lifetime of a SAS token issued against this account, as DD.HH:MM:SS.')
param sasExpirationPeriod string = '07.00:00:00'

@description('Public IPs allowed to read flow log blobs directly (e.g. an analyst workstation egress IP).')
param allowedIpRules array = []

param tags object = {}

// The relaxations below are constraints of the Network Watcher flow log writer,
// an Azure first-party service outside our VNet — not relaxed hardening:
//
//   publicNetworkAccess must stay Enabled or the trusted Microsoft services
//   bypass never applies and no flow log can be written. The account is still
//   default-deny via networkAcls.
//
//   allowSharedKeyAccess must stay true: the flow log writer has no
//   managed-identity option.
//
// A private endpoint would give the writer no path, and a customer-managed key
// would have to live in the private-endpoint-only platform Key Vault, which this
// service cannot reach.
//
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  //checkov:skip=CKV_AZURE_59:publicNetworkAccess must stay Enabled or the trusted-services bypass never applies and no flow log can be written. The account is still default-deny via networkAcls.
  //checkov:skip=CKV_AZURE_206:ZRS is the deliberate default — geo-redundancy doubles cost on a high-volume write-heavy account holding transient logs. Set replicationType to Standard_GRS/GZRS where a compliance baseline demands it.
  name: name
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: replicationType
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
    // Bounds the damage if a SAS is ever minted against this account.
    sasPolicy: {
      sasExpirationPeriod: sasExpirationPeriod
      expirationAction: 'Log'
    }
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
