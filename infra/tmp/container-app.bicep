param envId string
param acrServer string
param searchEndpoint string
param openAIEndpoint string
param sessionPoolEndpoint string
param tagName string
param location string

// Use a tag to track the creation of the resource
var appExists = contains(resourceGroup().tags, tagName) && resourceGroup().tags[tagName] == 'true'

resource existingAgent 'Microsoft.App/containerApps@2024-02-02-preview' existing = if (appExists) {
  name: 'baseball-agent'
}

var containerImage = appExists ? existingAgent.properties.template.containers[0].image : 'mcr.microsoft.com/k8se/quickstart:latest'

resource baseballAgent 'Microsoft.App/containerApps@2024-02-02-preview' = if (!appExists) {
  name: 'baseball-agent'
  location: location
  properties: {
    environmentId: envId
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8000
        transport: 'Auto'
        stickySessions: {
          affinity: 'sticky'
        }
      }
      registries: [
        {
          server: acrServer
          identity: 'system-environment'
        }
      ]
    }
    template: {
      containers: [
        {
          // TODO: change this
          image: docker.io/nginx
          name: 'main'
          env: [
            {
              name: 'OLLAMA_ENDPOINT'
              value: ollamaEndpoint
            }
            {
              name: 'OPENAI_ENDPOINT'
              value: openAIEndpoint
            }
            {
              name: 'SESSIONS_ENDPOINT'
              value: sessionPoolEndpoint
            }
            // TODO: light this up
            //{
            //  name: 'DATABASE_ENDPOINT'
            //  value: postgresEndpoint
            //}
          ]
          resources: {
            cpu: 2
            memory: '4Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

output baseballAgent object = baseballAgent