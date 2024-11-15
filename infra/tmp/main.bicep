// Q: is this going to cause a problem
targetScope = 'resourceGroup'

var openAIAccountName = 'openai-${uniqueString(resourceGroup().id)}'

@description('The region where the Azure OpenAI account will be created.')
param azureOpenAILocation string = resourceGroup().location


// putting this into australia east
param sessionPoolLocation string = 'Australia East'
param containerAppsLocation string = 'Australia East'

var trimmedResourceGroupLocation = trim(toLower(resourceGroup().location))
var actualSessionPoolLocation = !empty(sessionPoolLocation) ? sessionPoolLocation : (trimmedResourceGroupLocation == 'australiaeast' || trimmedResourceGroupLocation == 'swedencentral' ? resourceGroup().location : 'North Central US')


var acrName = 'crlabregistry${uniqueString(resourceGroup().id)}'
var logAnalyticsWorkspaceName = 'log-lab-loganalytics-${uniqueString(resourceGroup().id)}'
var acaEnvName = 'aca-ignite-demo'
var sessionPoolName = 'aca-ignite-demo'
var storageAccountName = 'stlab${uniqueString(resourceGroup().id)}'

// we use this as a marker to check for resource existence
var tagName = 'resourcesExist'


// TODO: this is currently public do we care to make this part of the vnet?
resource openAIAccount 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' = {
  name: openAIAccountName
  location: azureOpenAILocation
  sku: {
    name: 'S0'
  }
  kind: 'OpenAI'
  properties: {
    publicNetworkAccess: 'Enabled'
    customSubDomainName: openAIAccountName
  }
}

resource ada002 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = {
  parent: openAIAccount
  name: 'text-embedding-ada-002'
  sku: {
    name: 'Standard'
    capacity: 150
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'text-embedding-ada-002'
      version: '2'
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    currentCapacity: 150
    raiPolicyName: 'Microsoft.DefaultV2'
  }
}

resource llmmodel 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = {
  parent: openAIAccount
  name: 'llmmodel'
  sku: {
    name: 'Standard'
    capacity: 100
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o-mini'
      version: '2024-07-18'
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    currentCapacity: 100
    raiPolicyName: 'Microsoft.DefaultV2'
  }
  dependsOn: [
    ada002
  ]
}




resource registry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  sku: {
    name: 'Premium'
  }
  name: acrName
  location: containerAppsLocation
  tags: {}
  properties: {
    adminUserEnabled: false
    policies: {
      azureADAuthenticationAsArmPolicy: {
        status: 'enabled'
      }
    }
    encryption: {
      status: 'disabled'
    }
    anonymousPullEnabled: false
    metadataSearch: 'Enabled'
  }
}


resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: resourceGroup().location
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  })
}

// TODO: replace this with the one we already have
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



// Q: will API version work for serverless GPU?
// TODO: put this on the vnet
resource env 'Microsoft.App/managedEnvironments@2024-02-02-preview' = {
  name: acaEnvName
  location: containerAppsLocation
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    workloadProfiles: [
      {
          "workloadProfileType": "Consumption",
          "name": "Consumption"
      },
      {
          "workloadProfileType": "Consumption-GPU-NC8as-T4",
          "name": "NC8as-T4"
      },
      {
          "workloadProfileType": "Consumption-GPU-NC24-A100",
          "name": "NC24-A100"
      }
    ]
  }
  identity: {
    type: 'SystemAssigned'
  }
}


var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
resource acrRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(registry.id, acrPullRoleId, env.id)
  scope: registry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
    principalId: env.identity.principalId
    principalType: 'ServicePrincipal'
  }
}


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


module sessionPoolModule 'session-pool.bicep' = {
  name: 'session-pool'
  params: {
    name: sessionPoolName
    location: actualSessionPoolLocation
  }
}

var sessionPool = sessionPoolModule.outputs.sessionPool


module ollamaModel 'ollama-app.bicep' = {
  name: 'ollama-model'
  params: {
    envId: env.id
    acrServer: registry.properties.loginServer
    tagName: tagName
    location: containerAppsLocation
  }
}

module baseballAgent 'container-app.bicep' = {
  name: 'container-app'
  params: {
    envId: env.id
    searchEndpoint: 'https://${aiSearch.name}.search.windows.net'
    openAIEndpoint: openAIAccount.properties.endpoint
    sessionPoolEndpoint: sessionPool.properties.poolManagementEndpoint
    acrServer: registry.properties.loginServer
    tagName: tagName
    location: containerAppsLocation
  }
  dependsOn: [
    ollamaModel
  ]
}


// Q: same question here, why are we doing this via module
module sessionPoolRoleAssignment 'session-pool-role-assignment.bicep' = {
  name: 'session-pool-role-assignment'
  params: {
    chatApp: chatApp.outputs.chatApp
    sessionPoolName: sessionPoolName
  }
  dependsOn: [
    sessionPoolModule
    baseballAgent
  ]
}


var openAIUserRoleId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
resource appOpenAIUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(openAIAccount.id, openAIUserRoleId, resourceGroup().id, 'baseballAgent')
  scope: openAIAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', openAIUserRoleId)
    principalId: chatApp.outputs.chatApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}



resource tags 'Microsoft.Resources/tags@2024-03-01' = {
  name: 'default'
  properties: {
    tags: {
      '${tagName}': 'true'
    }
  }
  dependsOn: [
    baseballAgent
    ollamaModel
  ]
}

output STORAGE_ACCOUNT_NAME string = storageAccount.name
output ACR_NAME string = registry.name
output RESOURCE_GROUP_NAME string = resourceGroup().name
output CONTAINER_APP_URL string = 'https://${chatApp.outputs.chatApp.properties.configuration.ingress.fqdn}'
