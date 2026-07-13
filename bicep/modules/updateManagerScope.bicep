targetScope = 'subscription'

@description('Dynamic scope: enrol tagged VMs across the subscription in a maintenance configuration.')
param name string
param maintenanceConfigurationId string
param patchTagName string = 'patch-schedule'
param patchTagValue string = 'default'

resource dynamicScope 'Microsoft.Maintenance/configurationAssignments@2023-04-01' = {
  name: name
  properties: {
    maintenanceConfigurationId: maintenanceConfigurationId
    filter: {
      resourceTypes: [
        'Microsoft.Compute/virtualMachines'
      ]
      tagSettings: {
        filterOperator: 'All'
        tags: {
          '${patchTagName}': [
            patchTagValue
          ]
        }
      }
    }
  }
}
