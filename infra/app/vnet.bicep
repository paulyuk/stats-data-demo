@description('Specifies the name of the virtual network.')
param vNetName string

@description('Specifies the location.')
param location string = resourceGroup().location

@description('Specifies the name of the subnet for the Event Hubs private endpoint.')
param eventhubsSubnetName string = 'eventhubs'

@description('Specifies the name of the subnet for the uplaod data function app.')
param uploadDataSubnetName string = 'uploaddata'

@description('Specifies the name of the subnet for the uplaod data function app.')
param orchestrateIngestionSubnetName string = 'orchestrateingestion'

@description('Specifies the name of the subnet for the storage account.')
param storageSubnetName string = 'storage'

param tags object = {}


resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: vNetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    encryption: {
      enabled: false
      enforcement: 'AllowUnencrypted'
    }
    subnets: [
      {
        name: uploadDataSubnetName
        id: resourceId('Microsoft.Network/virtualNetworks/subnets', vNetName, uploadDataSubnetName)
        properties: {
          addressPrefixes: [
            '10.0.0.0/24'
          ]
          delegations: [
            {
              name: '${uploadDataSubnetName}delegation'
              id: resourceId('Microsoft.Network/virtualNetworks/subnets/delegations', vNetName, uploadDataSubnetName, 'delegation')
              properties: {
                //Microsoft.App/environments is the correct delegation for Flex Consumption VNet integration
                serviceName: 'Microsoft.App/environments'
              }
              type: 'Microsoft.Network/virtualNetworks/subnets/delegations'
            }
          ]
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
      {
        name: orchestrateIngestionSubnetName
        id: resourceId('Microsoft.Network/virtualNetworks/subnets', vNetName, orchestrateIngestionSubnetName)
        properties: {
          addressPrefixes: [
            '10.0.1.0/24'
          ]
          delegations: [
            {
              name: '${orchestrateIngestionSubnetName}delegation'
              id: resourceId('Microsoft.Network/virtualNetworks/subnets/delegations', vNetName, orchestrateIngestionSubnetName, 'delegation')
              properties: {
                //Microsoft.App/environments is the correct delegation for Flex Consumption VNet integration
                serviceName: 'Microsoft.App/environments'
              }
              type: 'Microsoft.Network/virtualNetworks/subnets/delegations'
            }
          ]
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
      {
        name: storageSubnetName
        id: resourceId('Microsoft.Network/virtualNetworks/subnets', vNetName, storageSubnetName)
        properties: {
          addressPrefixes: [
            '10.0.2.0/24'
          ]
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
      {
        name: eventhubsSubnetName
        id: resourceId('Microsoft.Network/virtualNetworks/subnets', vNetName, eventhubsSubnetName)
        properties: {
          addressPrefixes: [
            '10.0.3.0/24'
          ]
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
    ]
    virtualNetworkPeerings: []
    enableDdosProtection: false
  }
}

output uploadDataSubnetName string = virtualNetwork.properties.subnets[0].name
output uploadDataSubnetID string = virtualNetwork.properties.subnets[0].id
output orchestrateIngestionSubnetName string = virtualNetwork.properties.subnets[1].name
output orchestrateIngestionSubnetID string = virtualNetwork.properties.subnets[1].id
output storageSubnetName string = virtualNetwork.properties.subnets[2].name
output storageSubnetID string = virtualNetwork.properties.subnets[2].id
output eventhubsSubnetName string = virtualNetwork.properties.subnets[3].name
output eventhubsSubnetID string = virtualNetwork.properties.subnets[3].id

