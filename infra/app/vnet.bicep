@description('Specifies the name of the virtual network.')
param vNetName string

@description('Specifies the location.')
param location string = resourceGroup().location

@description('Specifies the name of the subnet for the Event Hubs private endpoint.')
param servicebusSubnetName string = 'servicebus'

@description('Specifies the name of the subnet for the upload data function app.')
param uploadDataSubnetName string = 'uploaddata'

@description('Specifies the name of the subnet for the orchestrate function app.')
param orchestrateIngestionSubnetName string = 'orchestrateingestion'

@description('Specifies the name of the subnet for the ux function app.')
param uxSubnetName string = 'ux'

@description('Specifies the name of the subnet for the storage account.')
param storageSubnetName string = 'storage'

@description('Specifies the name of the subnet for Azure Container Apps')
param acaSubnetName string = 'containerapps'

@description('Specifies the name of the subnet for the postgreSQL server.')
param postgreSQLSubnetName string = 'postgresql'

param tags object = {}


resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-03-01' = {
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
        name: servicebusSubnetName
        id: resourceId('Microsoft.Network/virtualNetworks/subnets', vNetName, servicebusSubnetName)
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

      {
        name: postgreSQLSubnetName
          id: resourceId('Microsoft.Network/virtualNetworks/subnets', vNetName, postgreSQLSubnetName)
          properties: {
            addressPrefixes: [
              '10.0.4.0/28'
            ]
            delegations: [
              {
                name: '${postgreSQLSubnetName}delegation'
                properties: {
                  serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
                }
              }
            ]
            privateEndpointNetworkPolicies: 'Disabled'
            privateLinkServiceNetworkPolicies: 'Enabled'
          }
          type: 'Microsoft.Network/virtualNetworks/subnets'
      }

      {
        name: acaSubnetName
        id: resourceId('Microsoft.Network/virtualNetworks/subnets', vNetName, acaSubnetName)
        properties: {
          addressPrefixes: [
            '10.0.5.0/24'
          ]
          delegations: [
            {
              name: '${acaSubnetName}delegation'
              id: resourceId('Microsoft.Network/virtualNetworks/subnets/delegations', vNetName, acaSubnetName, 'delegation')
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
              type: 'Microsoft.Network/virtualNetworks/subnets/delegations'
        
            }
          ]

        }
      }

      {
        name: uxSubnetName
        id: resourceId('Microsoft.Network/virtualNetworks/subnets', vNetName, uxSubnetName)
        properties: {
          addressPrefixes: [
            '10.0.6.0/24'
          ]
          delegations: [
            {
              name: '${uxSubnetName}delegation'
              id: resourceId('Microsoft.Network/virtualNetworks/subnets/delegations', vNetName, uxSubnetName, 'delegation')
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
    ] // closing subnets

    virtualNetworkPeerings: []
    enableDdosProtection: false
  } // closing properties
} // closing resource

output uploadDataSubnetName string = virtualNetwork.properties.subnets[0].name
output uploadDataSubnetID string = virtualNetwork.properties.subnets[0].id
output orchestrateIngestionSubnetName string = virtualNetwork.properties.subnets[1].name
output orchestrateIngestionSubnetID string = virtualNetwork.properties.subnets[1].id
output storageSubnetName string = virtualNetwork.properties.subnets[2].name
output storageSubnetID string = virtualNetwork.properties.subnets[2].id
output servicebusSubnetName string = virtualNetwork.properties.subnets[3].name
output servicebusSubnetID string = virtualNetwork.properties.subnets[3].id

output postgreSQLSubnetName string = virtualNetwork.properties.subnets[4].name
output postgreSQLSubnetID string = virtualNetwork.properties.subnets[4].id

output acaSubnetName string = virtualNetwork.properties.subnets[5].name
output acaSubnetID string = virtualNetwork.properties.subnets[5].id

output uxSubnetName string = virtualNetwork.properties.subnets[6].name
output uxSubnetID string = virtualNetwork.properties.subnets[6].id
