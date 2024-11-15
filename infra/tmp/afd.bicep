@description('The location into which regionally scoped resources should be deployed. Note that Front Door is a global resource.')
param location string = resourceGroup().location

@description('The name of the container app to create.')
param appName string = '${resourceGroup().name}-app'

@description('The name of the environment to host the container app.')
param environmentName string = '${resourceGroup().name}-env'

@description('The name of the Front Door endpoint to create. This must be globally unique.')
param frontDoorEndpointName string = '${resourceGroup().name}-endpoint'

@description('The name of the Front Door profile to create. This must be globally unique.')
param frontDoorProfileName string = '${resourceGroup().name}-profile'

@description('The name of the Front Door origin to create. This must be globally unique.')
param frontDoorOriginName string = '${resourceGroup().name}-origin'

@description('The name of the Front Door origin group to create. This must be globally unique.')
param frontDoorOriginGroupName string = '${resourceGroup().name}-og'

@description('The name of the Front Door route to create. This must be globally unique.')
param frontDoorRouteName string = '${resourceGroup().name}-route'

@description('The name of the SKU to use when creating the Front Door profile.')
@allowed([
  'Premium_AzureFrontDoor'
])
param frontDoorSkuName string = 'Premium_AzureFrontDoor'

resource frontDoorProfile 'Microsoft.Cdn/profiles@2021-06-01' = {
  name: frontDoorProfileName
  location: 'global'
  sku: {
    name: frontDoorSkuName
  }
}

resource environment 'Microsoft.App/managedEnvironments@2024-02-02-preview' = {
  name: environmentName
  location: location
  properties: {
    workloadProfiles: [
      {
        workloadProfileType: 'Consumption'
      }
    ]
    publicNetworkAccess: 'Disabled'
  }
}

resource app 'Microsoft.App/containerApps@2024-03-01' = {
  name: appName
  location: location
  properties: {
    environmentId: environment.id
    workloadProfileName: 'Consumption'
    configuration: {
      ingress: {
        transport: 'Auto'
        external: true
      }
    }
    template: {
      containers: [
        {
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          name: 'simple-hello-world-container'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
            ephemeralStorage: '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 1
      }
    }
  }
}

resource frontDoorProfileName_frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2021-06-01' = {
  parent: frontDoorProfile
  name: '${frontDoorEndpointName}'
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource frontDoorProfileName_frontDoorOriginGroup 'Microsoft.Cdn/profiles/originGroups@2021-06-01' = {
  parent: frontDoorProfile
  name: '${frontDoorOriginGroupName}'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
    }
  }
}

resource frontDoorProfileName_frontDoorOriginGroupName_frontDoorOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2021-06-01' = {
  parent: frontDoorProfileName_frontDoorOriginGroup
  name: frontDoorOriginName
  properties: {
    hostName: app.properties.configuration.ingress.fqdn
    httpPort: 80
    httpsPort: 443
    originHostHeader: app.properties.configuration.ingress.fqdn
    priority: 1
    weight: 1000
    sharedPrivateLinkResource: {
      groupId: 'managedEnvironments'
      privateLink: {
        id: environment.id
      }
      privateLinkLocation: location
      requestMessage: 'please approve'
    }
  }
}

resource frontDoorProfileName_frontDoorEndpointName_frontDoorRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2021-06-01' = {
  parent: frontDoorProfileName_frontDoorEndpoint
  name: frontDoorRouteName
  properties: {
    originGroup: {
      id: frontDoorProfileName_frontDoorOriginGroup.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
  }
  dependsOn: [
    frontDoorProfileName_frontDoorOriginGroupName_frontDoorOrigin
  ]
}

output appHostName string = app.properties.configuration.ingress.fqdn
output frontDoorEndpointHostName string = frontDoorProfileName_frontDoorEndpoint.properties.hostName
