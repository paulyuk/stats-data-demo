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
param singleLineServiceBusQueueName string = ''
param fullFileServiceBusQueueName string = ''
param serviceBusNamespaceFQDN string = ''
param instanceMemoryMB int = 2048
param maximumInstanceCount int = 100
param deploymentStorageContainerName string
param identityId string = ''
param identityClientId string = ''
param dataUploadContanerName string = 'data'


module app '../core/host/functions-flexconsumption.bicep' = {
  name: '${serviceName}-functions-flexconsumption'
  params: {
    name: name
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    identityType: 'UserAssigned'
    identityId: identityId
    appSettings: union(appSettings,
      {
        SERVICEBUS_CONNECTION__fullyQualifiedNamespace: serviceBusNamespaceFQDN
        SERVICEBUS_CONNECTION__clientId : identityClientId
        SERVICEBUS_CONNECTION__credential : 'managedidentity'
        AzureWebJobsStorage__clientId : identityClientId
        AzureWebJobsStorage__credential : 'managedidentity'
        SINGLE_LINE_SERVICEBUS_QUEUE_NAME: singleLineServiceBusQueueName
        FULL_FILE_SERVICEBUS_QUEUE_NAME: fullFileServiceBusQueueName
        STORAGE_CONTAINER_CSV: dataUploadContanerName
        AZURE_CLIENT_ID: identityClientId
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
output SERVICE_API_RESOURCE_ID string = app.outputs.resourceId
