@description('Private DNS zones linked to the given virtual networks.')
param zones array
@description('Array of { name, id } objects for VNets to link.')
param virtualNetworks array
param tags object = {}

resource dnsZones 'Microsoft.Network/privateDnsZones@2024-06-01' = [
  for zone in zones: {
    name: zone
    location: 'global'
    tags: tags
  }
]

resource links 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [
  for pair in flatten(map(range(0, length(zones)), zi => map(range(0, length(virtualNetworks)), vi => {
    zoneIndex: zi
    vnetIndex: vi
  }))): {
    parent: dnsZones[pair.zoneIndex]
    name: 'link-${virtualNetworks[pair.vnetIndex].name}'
    location: 'global'
    tags: tags
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: virtualNetworks[pair.vnetIndex].id
      }
    }
  }
]

output zoneIds array = [
  for (zone, i) in zones: {
    name: zone
    id: dnsZones[i].id
  }
]
