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
    $result = az deployment group create --name "Deploy-$(Get-Random)" --resource-group $ResourceGroup --template-file $PSScriptRoot/main.bicep --parameters principalId=$SignedInUserId | ConvertFrom-Json

    if ($LASTEXITCODE -ne 0) {
        throw "Deployment failed."
    }

    Write-Output "OK. Event Hub Data Owner role assigned to User $SignedInUserId for debugging."
    Write-Output ""

    Write-Output "Copy these values to config.toml:"
    Write-Output ""

    $eventHubNamespace = $result.properties.outputs.eventHubNamespace.value
    $eventHubName = $result.properties.outputs.eventHubName.value
    $serviceBusEndpoint = $result.properties.outputs.serviceBusEndpoint.value

    $storageAccountName = $result.properties.outputs.storageAccountName.value
    $storageAccountDfsEndpoint = $result.properties.outputs.storageAccountDfsEndpoint.value

    $appId = $result.properties.outputs.senderAppId.value
    $tenant = $account.homeTenantId

    Write-Output "[EventHub]"
    Write-Output "Namespace = ""$eventHubNamespace"""
    Write-Output "Name = ""$eventHubName"""
    Write-Output "ServiceBusEndpoint = ""$serviceBusEndpoint"""

    Write-Output ""
    Write-Output "[Storage]"
    Write-Output "AccountName = ""$storageAccountName"""
    Write-Output "DfsEndpoint = ""$storageAccountDfsEndpoint"""
    Write-Output ""

    Write-Output "Event hub sender identity:"
    Write-Output ""

    Write-Output "[Identity]"
    Write-Output "TenantId = ""$tenant"""
    Write-Output "AppId = ""$appId"""    
    Write-Output ""

    Write-Output "Need a client secret for this app? Run:"
    Write-Output "./scripts/Create-AppSecret.ps1 -AppId $appId"
}
catch {
    Write-Error "Failed to push containers: $_"
    Write-Error $_.ScriptStackTrace
    exit 1
}
