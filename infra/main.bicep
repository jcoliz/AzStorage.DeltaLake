//
// Provisions a complete set of needed production resources for this project
//
// Includes:
//    * Azure Event Hub
//    * Role assignment for Event Hub access
//

@description('Primary location for all resources')
param location string = resourceGroup().location

@description('Unique suffix for all resources in this deployment')
param suffix string = uniqueString(subscription().id,resourceGroup().id)

@description('The id that will be given data owner permission for the Event Hubs namespace')
param principalId string = ''

@description('The type of the given principal id')
param principalType string = 'User' // Can be User, Group, or ServicePrincipal

// Provision event hub
module eventHub '../../AzDeploy.Bicep/EventHub/ehub.bicep' = {
  name: 'eventHub'
  params: {
    suffix: suffix
    location: location
  }
}

// Provision role assignment for Event Hub access
module roleAssignment '../../AzDeploy.Bicep/EventHub/dataownerrole.bicep' = if (principalId != '') {
  name: 'roleAssignment'
  params: {
    eventHubName: eventHub.outputs.namespace
    principalId: principalId
    principalType: principalType
  }
}

output eventHubNamespace string = eventHub.outputs.namespace
output eventHubName string = eventHub.outputs.hub
output serviceBusEndpoint string = eventHub.outputs.serviceBusEndpoint
