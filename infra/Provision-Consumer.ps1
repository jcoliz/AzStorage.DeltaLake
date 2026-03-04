#
# This script deploys the `consumer.bicep` template to create the necessary resources for the consumer application
#

param(
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

    Write-Output "Retain these values to configure the consumer application:"
    Write-Output ""

    $keyVaultEndpoint = $result.properties.outputs.keyVaultEndpoint.value
    $consumerApplicationId = $result.properties.outputs.consumerApplicationId.value
    $consumerServicePrincipalId = $result.properties.outputs.consumerServicePrincipalId.value
    $consumerAppClientSecretId = $result.properties.outputs.consumerAppClientSecretId.value
    $tenant = $account.homeTenantId

    Write-Output "ConsumerApplicationId = ""$consumerApplicationId"""
    Write-Output "KeyVaultEndpoint = ""$keyVaultEndpoint"""
    Write-Output "ConsumerAppClientSecretId = ""$consumerAppClientSecretId"""
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
