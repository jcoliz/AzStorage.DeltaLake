//
// Provisions a complete set of needed production resources for this project
//
// Includes:
//    * Azure Event Hub
//    * User Role assignment for Event Hub access
//    * Azure Storage Account with hierarchical namespace enabled (Data Lake Storage Gen2)
//    * Storage Container for data lake tables
//    * Stream Analytics Job to read from Event Hub and write to Storage Account
//    * ASA Role assignment for Storage Account writer access
//    * ASA Role assignment for Event Hub reader access
//    * App Registration and Service Principal for Event Hub access from local development and docker container
//    * Role assignment for Event Hub access to the above Service Principal 
//

@description('Primary location for all resources')
param location string = resourceGroup().location

@description('Unique suffix for all resources in this deployment')
param suffix string = uniqueString(subscription().id,resourceGroup().id)

@description('The id that will be given data owner permission for the Event Hubs namespace')
param principalId string = ''

@description('The type of the given principal id')
param principalType string = 'User' // Can be User, Group, or ServicePrincipal

var containerName = 'datalake'

// Provision event hub sender application and service principal
module eventHubSenderApp './AzDeploy.Bicep/Entra/appsp.bicep' = {
  name: 'eventHubSenderApp'
  params: {
    appDisplayName: 'app-${resourceGroup().name}-ehub-sender'
    appDescription: 'Application and service principal used by docker container running locally to write to Event Hub'
  }
}

// Provision event hub
module eventHub './AzDeploy.Bicep/EventHub/ehub.bicep' = {
  name: 'eventHub'
  params: {
    suffix: suffix
    location: location
  }
}

// Provision user role assignment for owner Event Hub access, to enable debugging
module roleAssignment './AzDeploy.Bicep/EventHub/dataownerrole.bicep' = if (principalId != '') {
  name: 'roleAssignment'
  params: {
    eventHubName: eventHub.outputs.namespace
    principalId: principalId
    principalType: principalType
  }
}

// Provision event hub sender role assignment for the application
module eventHubSenderRole './AzDeploy.Bicep/EventHub/datasenderrole.bicep' = {
  name: 'eventHubSenderRole'
  params: {
    eventHubName: eventHub.outputs.namespace
    principalId: eventHubSenderApp.outputs.servicePrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Provision storage account for data lake
module storageAccount './AzDeploy.Bicep/Storage/storage.bicep' = {
  name: 'storageAccount'
  params: {
    suffix: suffix
    location: location
    isHnsEnabled: true
  }
}

// Provision storage container for data lake
module storageContainer './AzDeploy.Bicep/Storage/storcontainer.bicep' = {
  name: 'storageContainer'
  params: {
    account: storageAccount.outputs.storageName
    name: containerName
  }
}

// Provision user assigned managed identity for stream analytics job to use
module streamingJobIdentity './AzDeploy.Bicep/ManagedIdentity/userassigned.bicep' = {
  name: 'streamingJobIdentity'
  params: {
    suffix: suffix
    location: location
  }}

// Assign 'Azure Event Hubs Data Receiver' role on event hub for the stream analytics job
module eventHubDataReceiverRole './AzDeploy.Bicep/EventHub/datareceiverrole.bicep' = {
  name: 'eventHubDataReceiverRole'
  params: {
    eventHubNamespaceName: eventHub.outputs.namespace
    eventHubName: eventHub.outputs.hub
    principalId: streamingJobIdentity.outputs.servicePrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Assign 'Storage Blob Data Contributor' role on storage account for the stream analytics job
module storageBlobDataContributorRole './AzDeploy.Bicep/Storage/blobdatacontribroleusingparent.bicep' = {
  name: 'storageBlobDataContributorRole'
  params: {
    storageAccountName: storageAccount.outputs.storageName
    containerName: containerName
    principalId: streamingJobIdentity.outputs.servicePrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Provision stream analytics job
module streamingJobModule './AzDeploy.Bicep/StreamAnalytics/streamingjob.bicep' = {
  name: 'streamingJobModule'
  dependsOn: [
    eventHubDataReceiverRole
    storageBlobDataContributorRole
  ]
  params: {
    suffix: suffix
    location: location
    identityName: streamingJobIdentity.outputs.identityName
    inputs: [
      {
        name: 'Input'
        properties: {
          type: 'Stream'
          datasource: {
            type: 'Microsoft.ServiceBus/EventHub'
            properties: {
              consumerGroupName: ''
              eventHubName: eventHub.outputs.hub
              serviceBusNamespace: eventHub.outputs.namespace
              authenticationMode: 'Msi'
            }
          }
          compression: {
            type: 'None'
          }
          serialization: {
            type: 'Json'
            properties: {
              encoding: 'UTF8'
            }
          }
        }
      }
    ]
    outputs:  [
      {
        name: 'DataLake'
        properties: {
          datasource: {
            type: 'Microsoft.Storage/Blob'
            properties: {
              storageAccounts: [
                {
                  accountName: storageAccount.outputs.storageName
                }
              ]
              container: containerName
              authenticationMode: 'Msi'
            }
          }
          serialization: {
            properties: {
              deltaTablePath: 'metrics2'
            }
            type: 'Delta'
          }
          timeWindow: '00:00:30'
          sizeWindow: 3
        }
      }
    ]

    query: 'SELECT\n\t*\nINTO\n\t[DataLake]\nFROM\n\t[Input]'
  }
}

output eventHubNamespace string = eventHub.outputs.namespace
output eventHubName string = eventHub.outputs.hub
output serviceBusEndpoint string = eventHub.outputs.serviceBusEndpoint
output storageAccountName string = storageAccount.outputs.storageName
output storageAccountDfsEndpoint string = storageAccount.outputs.storageEndpoint.dfs
output senderAppId string = eventHubSenderApp.outputs.applicationId
