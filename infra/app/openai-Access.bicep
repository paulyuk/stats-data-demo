param openAIAccountName string
param baseballAgentPrincipal string

resource openAIAccount 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' existing = {
  name: openAIAccountName
}

var openAIUserRoleId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
resource appOpenAIUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  //name: guid(openAIAccountName, openAIUserRoleId, resourceGroup().id, 'baseballAgent')
  name: guid(openAIAccountName)
  //name: guid(openAIUserRoleId)
  //name: guid(resourceGroup().id)
  //name: guid('baseballAgent')
  scope: openAIAccount
  //scope: rg
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', openAIUserRoleId)
    principalId: baseballAgentPrincipal
    principalType: 'ServicePrincipal'
  }
}