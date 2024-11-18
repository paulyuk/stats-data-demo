param openAIAccountName string
param azureOpenAILocation string

// TODO: should we check for existence in case of re-runs?
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
    name: 'GlobalStandard'
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


output openAIAccount object = openAIAccount
output llmmodelName string = llmmodel.name
output embeddingsModelName string = ada002.name
