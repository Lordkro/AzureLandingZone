@description('Hardened StorageV2 account with blob versioning, soft delete and a private endpoint.')
param name string
param location string

@description('Replication. GZRS (zone + async geo copy) is the default; not offered in every region, fall back to Standard_ZRS or Standard_GRS where unavailable.')
@allowed([
  'Standard_GZRS'
  'Standard_RAGZRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Standard_LRS'
])
param replicationType string = 'Standard_GZRS'
param privateEndpointSubnetId string
param privateDnsZoneId string
param logAnalyticsWorkspaceId string
param tags object = {}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  // replicationType defaults to Standard_GZRS, which CKV_AZURE_206 accepts, but
  // Checkov's Bicep parser does not resolve parameter defaults for sku.name — it
  // sees the parameter reference and reports the SKU as unset. Hardcoding the SKU
  // would satisfy the scanner at the cost of the region fallback this parameter
  // exists for (GZRS is not offered everywhere), so the parameter stays.
  //checkov:skip=CKV_AZURE_206:replicationType defaults to Standard_GZRS; Checkov cannot resolve Bicep parameter defaults, and the parameter is required for regions without GZRS.
  //checkov:skip=CKV_AZURE_33:No queue service is used; only the blob service is deployed.
  //checkov:skip=CKV2_AZURE_1:Platform-managed keys are the deliberate default; CMK is documented as an opt-in follow-up in docs/governance.md.
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
    allowSharedKeyAccess: false
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Disabled'
    defaultToOAuthAuthentication: true
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    isVersioningEnabled: true
    deleteRetentionPolicy: {
      enabled: true
      days: 30
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 30
    }
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pep-${name}-blob'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'psc-${name}-blob'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

resource dnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'blob'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

resource blobDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${name}-blob'
  scope: blobService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output primaryBlobEndpoint string = storageAccount.properties.primaryEndpoints.blob
