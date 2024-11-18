param administratorLogin string
@secure()
param administratorLoginPassword string
param location string = resourceGroup().location
param tags object = {}
param serverName string
param serverEdition string = 'GeneralPurpose'
param skuSizeGB int = 128
param dbInstanceType string = 'Standard_D4ds_v5'
param haMode string = 'Disabled'
param version string = '16'
param delegatedSubnetResourceId string = ''
param privateDnsZoneArmResourceId string = ''

resource serverName_resource 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: serverName
  location: location
  tags: tags
  sku: {
    name: dbInstanceType
    tier: serverEdition
  }
  properties: {
    version: version
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    network: {
      delegatedSubnetResourceId: (empty(delegatedSubnetResourceId) ? null : delegatedSubnetResourceId)
      privateDnsZoneArmResourceId: (empty(privateDnsZoneArmResourceId) ? null : privateDnsZoneArmResourceId)
    }
    highAvailability: {
      mode: haMode
    }
    storage: {
      storageSizeGB: skuSizeGB
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
  }
}

//TODO; Change to managed identity
output endpoint string = 'postgresql://myadmin:${administratorLoginPassword}@${serverName_resource.properties.fullyQualifiedDomainName}:5432/postgres'
