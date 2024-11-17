param acaEnvName string
param containerAppsLocation string
param acrName string
param subnetID string

// TODO: put this on the vnet
resource env 'Microsoft.App/managedEnvironments@2024-02-02-preview' = {
  name: acaEnvName
  location: containerAppsLocation
  properties: {
    // skipping this for now
    //appLogsConfiguration: {
    //  destination: 'log-analytics'
    //  logAnalyticsConfiguration: {
    //    customerId: logAnalyticsWorkspace.properties.customerId
    //    sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
    //  }
    //}
    workloadProfiles: [
      {
          workloadProfileType: 'Consumption'
          name: 'Consumption'
      }
    // Change to this if the T4 module is to be used 
    //  {
    //      workloadProfileType: 'Consumption-GPU-NC8as-T4'
    //      name: 'NC8as-T4'
    //  }
      {
          workloadProfileType: 'Consumption-GPU-NC24-A100'
          name: 'NC24-A100'
      }
    ]
    vnetConfiguration: {
            internal: true
            infrastructureSubnetId: subnetID
        }
  }
  identity: {
    type: 'SystemAssigned'
  }
}


// ACA: Registry to be used
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


// give the environment pull access to the registry
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

output acaEnvId string = env.id
output RegistryId string = registry.id
output loginServer string = registry.properties.loginServer
