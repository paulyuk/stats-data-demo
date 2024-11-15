// Parameters
@description('Specifies the name of the virtual network.')
param virtualNetworkName string
param dnsZoneName string = 'postgresserver'
param tags object = {}


// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2024-03-01' existing = {
  name: virtualNetworkName
}

// Private DNS Zones
resource sbPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: '${dnsZoneName}.postgres.database.azure.com'
  location: 'global'
  tags: tags
  properties: {}
  dependsOn: [
    vnet
  ]
}

// Virtual Network Links
resource sbPrivateDnsZoneVirtualNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: sbPrivateDnsZone
  name: 'link_to_${toLower(virtualNetworkName)}'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

output privateDnsZoneArmResourceId string = sbPrivateDnsZone.id
