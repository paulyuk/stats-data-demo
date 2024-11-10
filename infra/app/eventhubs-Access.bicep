param eventHubsNamespaceName string
param eventHubName string
param principalIds array
param roleId string

resource eventHubsResource 'Microsoft.EventHub/namespaces/eventhubs@2023-01-01-preview' existing = {
  name: '${eventHubsNamespaceName}/${eventHubName}'
}

// Allow access from an identity to Event Hubs using a managed identity and specific role definition
resource eventHubsRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = [for principalId in principalIds: {
  name: guid(eventHubsResource.id, principalId, roleId)
  scope: eventHubsResource
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleId)
    principalId: principalId
  }
}]
