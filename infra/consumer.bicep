//
// Provisions downstream consumer resources for this project, including:
//
//    * App Registration, Service Principal, and Client Secret for consuming data from storage account
//    * Key Vault to store client secret for above Service Principal
//    * Key Vault Secrets Owner role assignment for designated principal (usually current user)
//    * Store the client secret in Key Vault and output the secret identifier as an output of this module
//

@description('Primary location for all resources')
param location string = resourceGroup().location

@description('Unique suffix for all resources in this deployment')
param suffix string = uniqueString(subscription().id,resourceGroup().id)

@description('The id that will be given data owner permission for the Event Hubs namespace')
param officerPrincipalId string = ''

@description('The type of the given principal id')
param officerPrincipalType string = 'User' // Can be User, Group, or ServicePrincipal

var appDisplayName = 'app-${resourceGroup().name}-consumer'

// Deploy key vault
module keyVault './AzDeploy.Bicep/Keyvault/keyvault.bicep' = {
  name: 'keyVault'
  params: {
    suffix: suffix
    location: location
  }
}

// Deploy role assignment for Key Vault Secrets Officer
module secretsOfficerRole './AzDeploy.Bicep/Keyvault/secretsofficerrole.bicep' = if (officerPrincipalId != '') {
  name: 'secretsOfficerRole'
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: officerPrincipalId
    principalType: officerPrincipalType
  }
}

// Create the consumer application and service principal
module consumerApp './AzDeploy.Bicep/Entra/appsp.bicep' = {
  name: 'consumerApp'
  params: {
    appDisplayName: appDisplayName
    appDescription: 'Application and service principal used by docker container running locally to read secrets from Key Vault'
  }
}

// Output the key vault name
output keyVaultName string = keyVault.outputs.name

// Output the key vault endpoint
output keyVaultEndpoint string = keyVault.outputs.endpoint 

// Output the application display name
output appDisplayName string = appDisplayName

// Output the consumer application id
output consumerApplicationId string = consumerApp.outputs.applicationId

// Output the consumer service principal id
output consumerServicePrincipalId string = consumerApp.outputs.servicePrincipalId
