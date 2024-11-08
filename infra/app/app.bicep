param name string
param location string = resourceGroup().location
param tags object = {}
param applicationInsightsName string = ''
param appServicePlanId string
param appSettings object = {}
param runtimeName string
param runtimeVersion string
param serviceName string = ''
param storageAccountName string
param virtualNetworkSubnetId string = ''
param eventHubFQDN string = ''
param eventHubName string = ''
param instanceMemoryMB int = 2048
param maximumInstanceCount int = 100
param deploymentStorageContainerName string


module app '../core/host/functions-flexconsumption.bicep' = {
  name: '${serviceName}-functions-flexconsumption'
  params: {
    name: name
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    appSettings: union(appSettings,
      {
        EVENTHUB_CONNECTION__fullyQualifiedNamespace: eventHubFQDN
        EVENT_HUB: eventHubName
      })
    applicationInsightsName: applicationInsightsName
    appServicePlanId: appServicePlanId
    runtimeName: runtimeName
    runtimeVersion: runtimeVersion
    storageAccountName: storageAccountName
    instanceMemoryMB: instanceMemoryMB //needed for Flex
    maximumInstanceCount: maximumInstanceCount //needed for Flex
    virtualNetworkSubnetId: virtualNetworkSubnetId
    deploymentStorageContainerName: deploymentStorageContainerName
  }
}

output SERVICE_API_IDENTITY_PRINCIPAL_ID string = app.outputs.identityPrincipalId
output SERVICE_API_NAME string = app.outputs.name
output SERVICE_API_URI string = app.outputs.uri
