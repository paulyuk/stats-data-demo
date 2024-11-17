param envId string
param tagName string
param location string
// we keep this just in case we need a custom ollama container
param acrServer string

// Use a tag to track the creation of the resource
var appExists = contains(resourceGroup().tags, tagName) && resourceGroup().tags[tagName] == 'true'

resource existingAgent 'Microsoft.App/containerApps@2024-02-02-preview' existing = if (appExists) {
  name: 'ollama-model'
}

var containerImage = appExists ? existingAgent.properties.template.containers[0].image : 'mcr.microsoft.com/k8se/quickstart:latest'

resource ollamaModel 'Microsoft.App/containerApps@2024-02-02-preview' = if (!appExists) {
  name: 'ollama-model'
  location: location
  properties: {
    environmentId: envId
    // Change to this if the T4 module is used
    //workloadProfileName: 'NC8as-T4'
    workloadProfileName: 'NC24-A100'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        targetPort: 11434
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
          image: 'docker.io/ollama/ollama'
          name: 'ollama-endpoint'
          resources: {
            // Change to this if the T4 module is to be used 
            //cpu: 8
            //memory: '56Gi'
            cpu: 24
            memory: '220Gi'
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


output endpoint string = 'https://${ollamaModel.properties.configuration.ingress.fqdn}'
