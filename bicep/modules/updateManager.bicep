@description('Azure Update Manager maintenance configuration for guest OS patching.')
param name string
param location string
param startDateTime string
param duration string = '03:55'
param recurEvery string = '1Week Sunday'
param tags object = {}

resource maintenanceConfig 'Microsoft.Maintenance/maintenanceConfigurations@2023-04-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    maintenanceScope: 'InGuestPatch'
    extensionProperties: {
      InGuestPatchMode: 'Platform'
    }
    maintenanceWindow: {
      startDateTime: startDateTime
      duration: duration
      timeZone: 'UTC'
      recurEvery: recurEvery
    }
    installPatches: {
      rebootSetting: 'IfRequired'
      windowsParameters: {
        classificationsToInclude: [
          'Critical'
          'Security'
          'UpdateRollup'
          'Definition'
        ]
      }
      linuxParameters: {
        classificationsToInclude: [
          'Critical'
          'Security'
        ]
      }
    }
  }
}

output maintenanceConfigurationId string = maintenanceConfig.id
