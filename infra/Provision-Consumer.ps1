#
# This script deploys the `consumer.bicep` template to create the necessary resources for the consumer application
#
# NOTE: https://learn.microsoft.com/en-us/graph/templates/bicep/limitations#application-passwords-are-not-supported-for-applications-and-service-principals
# We cannot create a client secret for the consumer application using Microsoft Graph API in the Bicep template, so we have to create the application and service principal first
# We will later need to create the client secret and store it in Key Vault. The script will output the necessary information to configure the consumer application, including the application ID, Key Vault endpoint, client secret name, and tenant ID.
#

param(
    # Rwquired parameter: KeyConsumerPrincipalId - the principal ID of the consumer application that will be retrieving the application secret
    [Parameter(Mandatory=$true)]
    [string]
    $KeyConsumerPrincipalId,
    [Parameter()]
    [string]
    $ResourceGroup = "rg-ehub-deltalake",
    [Parameter()]
    [string]
    $Location = "westus2"
)

try {
    Write-Host "Checking Azure Subscription..." -ForegroundColor Cyan
    $account = az account show 2>&1 | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get Azure account information. Please run 'az login' first."
    }

    Write-Output "Creating Resource Group $ResourceGroup in $Location"
    az group create --name $ResourceGroup --location $Location
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create resource group."
    }

    # Get current user using az ad signed-in-user show --query "id" -o tsv
    $SignedInUserId = az ad signed-in-user show --query "id" -o tsv

    Write-Output "Deploying to Resource Group $ResourceGroup"
    $result = az deployment group create --name "Deploy-$(Get-Random)" --resource-group $ResourceGroup --template-file $PSScriptRoot/consumer.bicep --parameters officerPrincipalId=$SignedInUserId | ConvertFrom-Json

    if ($LASTEXITCODE -ne 0) {
        throw "Deployment failed."
    }

    $keyVaultEndpoint = $result.properties.outputs.keyVaultEndpoint.value
    $keyVaultName = $result.properties.outputs.keyVaultName.value
    $consumerApplicationId = $result.properties.outputs.consumerApplicationId.value
    $consumerServicePrincipalId = $result.properties.outputs.consumerServicePrincipalId.value
    $appDisplayName = $result.properties.outputs.appDisplayName.value
    $tenant = $account.homeTenantId

    # Create the app secret - use 'password add' instead of 'reset' to get the credential ID
    $description = "Created by Provision-Consumer.ps1 on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")"
    $secretJson = az ad app credential reset --id $consumerApplicationId --display-name $description -o json
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create app secret."
    }

    $secretResult = $secretJson | ConvertFrom-Json
    $secretValue = $secretResult.password
    $secretName = "${appDisplayName}-ClientSecret"

    # Store the client secret in Key Vault using a Bicep template deployment
    $result = az deployment group create --name "Deploy-$(Get-Random)" --resource-group $ResourceGroup --template-file $PSScriptRoot/AzDeploy.Bicep/Keyvault/kvsecret.bicep --parameters keyVaultName=$keyVaultName secretName=$secretName secretValue=$secretValue | ConvertFrom-Json

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to store client secret in Key Vault."
    }

    # Assign the Secrets User role to the consumer key reader service principal for the created secret
    $result = az deployment group create --name "Deploy-$(Get-Random)" --resource-group $ResourceGroup --template-file $PSScriptRoot/AzDeploy.Bicep/Keyvault/secretsuseronsecretrole.bicep --parameters keyVaultName=$keyVaultName keyName=$secretName principalId=$KeyConsumerPrincipalId | ConvertFrom-Json

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to assign Secrets User role to the consumer key reader service principal."
    }

    Write-Output "Retain these values to configure the consumer application:"
    Write-Output ""

    Write-Output "ConsumerApplicationId = ""$consumerApplicationId"""
    Write-Output "KeyVaultEndpoint = ""$keyVaultEndpoint"""
    Write-Output "SecretName = ""$secretName"""
    Write-Output "ConsumerServicePrincipalId = ""$consumerServicePrincipalId"""
    Write-Output "TenantId = ""$tenant"""
    Write-Output ""
    Write-Output "Now you can deploy the producer resources using the Provision-Resources.ps1 script:"
    Write-Output "`t.\Provision-Resources.ps1 -ResourceGroup $ResourceGroup -Location $Location -DataReaderPrincipalId $consumerServicePrincipalId"
    Write-Output ""
}
catch {
    Write-Error "Failed to push containers: $_"
    Write-Error $_.ScriptStackTrace
    exit 1
}
