targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
@allowed(['australiaeast', 'eastasia', 'eastus', 'eastus2', 'northeurope', 'southcentralus', 'southeastasia', 'swedencentral', 'uksouth', 'westus2', 'eastus2euap'])
@metadata({
  azd: {
    type: 'location'
  }
})
param location string

// Optional parameters to override the default azd resource naming conventions. Update the main.parameters.json file to provide values. e.g.,:
param uploadDataServiceName string = ''
param uploadDataAppServicePlanName string = ''
param orchestrateIngestionServiceName string = ''
param orchestrateIngestionAppServicePlanName string = ''
param logAnalyticsName string = ''
param applicationInsightsDashboardName string = ''
param applicationInsightsName string = ''
param storageAccountName string = ''
param serviceBusNamespaceName string = ''
param vNetName string = ''
param resourceGroupName string = ''
param uploadDataUserAssignedIdentityName string = ''
param orchestrateUserAssignedIdentityName string = ''

@description('Additional id of the user or app to assign application roles to access the secured resources in this template.')
param principalId string = ''

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }
// Generate unique function app names if one is not provided.
var uploadDataAppName = !empty(uploadDataServiceName) ? uploadDataServiceName : '${abbrs.webSitesFunctions}uploaddata-${resourceToken}'
var orchestrateIngestionAppName = !empty(orchestrateIngestionServiceName) ? orchestrateIngestionServiceName : '${abbrs.webSitesFunctions}orchestrateingest-${resourceToken}'
// Generate a unique storage container name that will be used for Function App deployments.
var uploadDataDeploymentStorageContainerName = 'app-package-uploaddata-${take(resourceToken, 7)}'
var orchestrateIngestionDeploymentStorageContainerName = 'app-package-orchestrateingest-${take(resourceToken, 7)}'
var dataUploadContanerName = 'data-${take(resourceToken, 7)}'
var singleLineServiceBusQueueName = '${abbrs.serviceBusNamespacesQueues}singleline-${resourceToken}'
var fullFileServiceBusQueueName = '${abbrs.serviceBusNamespacesQueues}fullfile-${resourceToken}'


// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2024-07-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// Create a separate app service plan for each of the Flex Consumption apps (Flex Consumption apps don't share app service plans)
module uploadDataAppServicePlan 'core/host/appserviceplan.bicep' = {
  name: 'uploadDataAppServicePlan'
  scope: rg
  params: {
    name: !empty(uploadDataAppServicePlanName) ? uploadDataAppServicePlanName : '${abbrs.webServerFarms}uploaddata${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'FC1'
      tier: 'FlexConsumption'
      size: 'FC'
      family: 'FC'
    }
    reserved: true
  }
}

module orchestrateIngestionAppServicePlan 'core/host/appserviceplan.bicep' = {
  name: 'orchestrateIngestionAppServicePlan'
  scope: rg
  params: {
    name: !empty(orchestrateIngestionAppServicePlanName) ? orchestrateIngestionAppServicePlanName : '${abbrs.webServerFarms}orchestrateingest${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'FC1'
      tier: 'FlexConsumption'
      size: 'FC'
      family: 'FC'
    }
    reserved: true
  }
}

// User assigned managed identity to be used by the Function App to reach storage and service bus
module uploadDataUserAssignedIdentity './core/identity/userAssignedIdentity.bicep' = {
  name: 'uploadDataAssignedIdentity'
  scope: rg
  params: {
    location: location
    tags: tags
    identityName: !empty(uploadDataUserAssignedIdentityName) ? uploadDataUserAssignedIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}uploaddata-${resourceToken}'
  }
}

// The upload data application backend powered by Azure Functions Flex Consumption
module uploadData './app/app.bicep' = {
  name: 'uploaddata'
  scope: rg
  params: {
    name: uploadDataAppName
    serviceName: 'uploaddata'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    appServicePlanId: uploadDataAppServicePlan.outputs.id
    runtimeName: 'python'
    runtimeVersion: '3.11'
    instanceMemoryMB: 2048
    maximumInstanceCount: 250
    storageAccountName: storage.outputs.name
    deploymentStorageContainerName: uploadDataDeploymentStorageContainerName
    dataUploadContanerName: dataUploadContanerName
    identityId: uploadDataUserAssignedIdentity.outputs.identityId
    identityClientId: uploadDataUserAssignedIdentity.outputs.identityClientId
    appSettings: {
    }
    virtualNetworkSubnetId: serviceVirtualNetwork.outputs.uploadDataSubnetID
    singleLineServiceBusQueueName: singleLineServiceBusQueueName
    fullFileServiceBusQueueName: fullFileServiceBusQueueName
    serviceBusNamespaceFQDN: serviceBus.outputs.serviceBusNamespaceFQDN
  }
}

// User assigned managed identity to be used by the Function App to reach storage and service bus
module orchestrateUserAssignedIdentity './core/identity/userAssignedIdentity.bicep' = {
  name: 'orchestrateAssignedIdentity'
  scope: rg
  params: {
    location: location
    tags: tags
    identityName: !empty(orchestrateUserAssignedIdentityName) ? orchestrateUserAssignedIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}orchestrate-${resourceToken}'
  }
}
// The upload data application backend powered by Azure Functions Flex Consumption
module orchestrateIngestion './app/app.bicep' = {
  name: 'orchestrateingest'
  scope: rg
  params: {
    name: orchestrateIngestionAppName
    serviceName: 'orchestrateingest'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    appServicePlanId: orchestrateIngestionAppServicePlan.outputs.id
    runtimeName: 'python'
    runtimeVersion: '3.11'
    instanceMemoryMB: 2048
    maximumInstanceCount: 250
    storageAccountName: storage.outputs.name
    deploymentStorageContainerName: orchestrateIngestionDeploymentStorageContainerName
    identityId: orchestrateUserAssignedIdentity.outputs.identityId
    identityClientId: orchestrateUserAssignedIdentity.outputs.identityClientId
    appSettings: {
    }
    virtualNetworkSubnetId: serviceVirtualNetwork.outputs.orchestrateIngestionSubnetID
    singleLineServiceBusQueueName: singleLineServiceBusQueueName
    fullFileServiceBusQueueName: fullFileServiceBusQueueName
    serviceBusNamespaceFQDN: serviceBus.outputs.serviceBusNamespaceFQDN
  }
}

// Backing storage for Azure functions backend API
module storage './core/storage/storage-account.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    location: location
    tags: tags
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
    }
    containers: [{name: uploadDataDeploymentStorageContainerName}, {name: orchestrateIngestionDeploymentStorageContainerName}, {name: dataUploadContanerName}]
  }
}

var principalIds = [uploadData.outputs.SERVICE_API_IDENTITY_PRINCIPAL_ID, orchestrateIngestion.outputs.SERVICE_API_IDENTITY_PRINCIPAL_ID, principalId]

//Storage Blob Data Owner role, Storage Blob Data Contributor role, Storage Table Data Contributor role
// Allow access from apps to storage account using managed identity
var storageRoleIds = ['b7e6dc6d-f1e8-4753-8033-0f276bb0955b', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe', '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3']
module storageRoleAssignments 'app/storage-Access.bicep' = [for roleId in storageRoleIds: {
  name: 'blobRole${roleId}'
  scope: rg
  params: {
    storageAccountName: storage.outputs.name
    roleId: roleId
    principalIds: principalIds
  }
}]

// Service Bus
module serviceBus 'core/message/servicebus.bicep' = {
  name: 'serviceBus'
  scope: rg
  params: {
    location: location
    tags: tags
    serviceBusNamespaceName: !empty(serviceBusNamespaceName) ? serviceBusNamespaceName : '${abbrs.serviceBusNamespaces}${resourceToken}'
    queues: [singleLineServiceBusQueueName, fullFileServiceBusQueueName]
  }
}

var ServiceBusRoleDefinitionIds  = ['090c5cfd-751d-490a-894a-3ce6f1109419', '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'] //Azure Service Bus Data Owner and Data Receiver roles
// Allow access from processor to Service Bus using a managed identity and Azure Service Bus Data Owner and Data Receiver roles
module ServiceBusDataOwnerRoleAssignment 'app/servicebus-Access.bicep' = [for roleId in ServiceBusRoleDefinitionIds: {
  name: 'sbRoleAssignment${roleId}'
  scope: rg
  params: {
    serviceBusNamespaceName: serviceBus.outputs.serviceBusNamespace
    roleDefinitionId: roleId
    principalIds: principalIds
  }
}]

// Virtual Network & private endpoint
module serviceVirtualNetwork 'app/vnet.bicep' = {
  name: 'serviceVirtualNetwork'
  scope: rg
  params: {
    location: location
    tags: tags
    vNetName: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
  }
}

module storagePrivateEndpoint 'app/storage-PrivateEndpoint.bicep' = {
  name: 'storagePrivateEndpoint'
  scope: rg
  params: {
    location: location
    tags: tags
    virtualNetworkName: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    subnetName: serviceVirtualNetwork.outputs.storageSubnetName
    resourceName: storage.outputs.name
  }
}

module servicePrivateEndpoint 'app/servicebus-privateEndpoint.bicep' = {
  name: 'servicePrivateEndpoint'
  scope: rg
  params: {
    location: location
    tags: tags
    virtualNetworkName: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    subnetName: serviceVirtualNetwork.outputs.servicebusSubnetName
    sbNamespaceId: serviceBus.outputs.namespaceId
  }
}

// Monitor application with Azure Monitor
module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    tags: tags
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: !empty(applicationInsightsDashboardName) ? applicationInsightsDashboardName : '${abbrs.portalDashboards}${resourceToken}'
  }
}

// App outputs
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output UPLOAD_DATA_BASE_URL string = uploadData.outputs.SERVICE_API_URI
output ORCHESTRATE_INGEST_BASE_URL string = orchestrateIngestion.outputs.SERVICE_API_URI
output RESOURCE_GROUP string = rg.name
output UPLOAD_DATA_FUNCTION_APP_NAME string = uploadData.outputs.SERVICE_API_NAME
output ORCHESTRATE_INGEST_FUNCTION_APP_NAME string = orchestrateIngestion.outputs.SERVICE_API_NAME
