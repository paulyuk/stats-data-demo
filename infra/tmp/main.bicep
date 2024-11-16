// Q: is this going to cause a problem
targetScope = 'resourceGroup'



@description('The region where the Azure OpenAI account will be created.')
param azureOpenAILocation string = resourceGroup().location


// putting this into australia east
param sessionPoolLocation string = 'Australia East'
param containerAppsLocation string = 'Australia East'

var trimmedResourceGroupLocation = trim(toLower(resourceGroup().location))
var actualSessionPoolLocation = !empty(sessionPoolLocation) ? sessionPoolLocation : (trimmedResourceGroupLocation == 'australiaeast' || trimmedResourceGroupLocation == 'swedencentral' ? resourceGroup().location : 'North Central US')


// TODO: find a solution for this
var logAnalyticsWorkspaceName = 'log-lab-loganalytics-${uniqueString(resourceGroup().id)}'

var storageAccountName = 'stlab${uniqueString(resourceGroup().id)}'













// we don't need this
// resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
//   name: storageAccountName
//   location: resourceGroup().location
//   sku: {
//     name: 'Standard_LRS'
//   }
//   kind: 'StorageV2'

//   resource fileService 'fileServices@2023-05-01' = {
//     name: 'default'
//     resource share 'shares@2023-05-01' = {
//       name: 'pdfs'
//       properties: {
//         enabledProtocols: 'SMB'
//         accessTier: 'TransactionOptimized'
//         shareQuota: 1024
//       }
//     }
//   }
// }





// Q: why are we using a module for this now?
// resource sessionPool 'Microsoft.App/sessionPools@2024-02-02-preview' = {
//   name: sessionPoolName
//   location: sessionPoolLocation
//   properties: {
//     poolManagementType: 'Dynamic'
//     containerType: 'PythonLTS'
//     scaleConfiguration: {
//       maxConcurrentSessions: 50
//     }
//     dynamicPoolConfiguration: {
//       executionType: 'Timed'
//       cooldownPeriodInSeconds: 300
//     }
//     sessionNetworkConfiguration: {
//       status: 'EgressDisabled'
//     }
//   }
// }











output STORAGE_ACCOUNT_NAME string = storageAccount.name
output ACR_NAME string = registry.name
output RESOURCE_GROUP_NAME string = resourceGroup().name
output CONTAINER_APP_URL string = 'https://${chatApp.outputs.chatApp.properties.configuration.ingress.fqdn}'
