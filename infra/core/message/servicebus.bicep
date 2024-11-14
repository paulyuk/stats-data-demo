param serviceBusNamespaceName string
param location string = resourceGroup().location
param tags object = {}
param queues array = []

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: serviceBusNamespaceName
  location: location
  tags: tags
  sku: {
    name: 'Premium'    
  }
  properties: {
    publicNetworkAccess: 'Disabled'
  }
}

resource serviceBusQueue  'Microsoft.ServiceBus/namespaces/queues@2022-01-01-preview' = [for queue in queues: {
  parent: serviceBusNamespace
  name: queue
}]

resource serviceBusManageAccessKey 'Microsoft.ServiceBus/namespaces/AuthorizationRules@2022-10-01-preview' existing = {
  parent: serviceBusNamespace
  name: 'RootManageSharedAccessKey'
}

output namespaceId string = serviceBusNamespace.id
output serviceBusNamespaceFQDN string = '${serviceBusNamespace.name}.servicebus.windows.net'
output serviceBusManageAccessKeyId string = serviceBusManageAccessKey.id
output serviceBusNamespace string = serviceBusNamespace.name
