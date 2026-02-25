param(
    [Parameter()]
    [string]
    $ResourceGroup = "ehub-federation",
    [Parameter()]
    [string]
    $Location = "westus2"
)

try {
    Write-Output "Creating Resource Group $ResourceGroup in $Location"
    az group create --name $ResourceGroup --location $Location

    # Get current user using az ad signed-in-user show --query "id" -o tsv
    $ServicePrincipal = az ad signed-in-user show --query "id" -o tsv

    Write-Output "Deploying to Resource Group $ResourceGroup"
    $result = az deployment group create --name "Deploy-$(Get-Random)" --resource-group $ResourceGroup --template-file $PSScriptRoot/main.bicep --parameters principalId=$ServicePrincipal | ConvertFrom-Json

    Write-Output "OK. Role assigned to $ServicePrincipal for Event Hub access."
    Write-Output ""

    Write-Output "Copy these values to config.toml:"
    Write-Output ""

    $eventHubNamespace = $result.properties.outputs.eventHubNamespace.value
    $eventHubName = $result.properties.outputs.eventHubName.value
    $serviceBusEndpoint = $result.properties.outputs.serviceBusEndpoint.value

    $storageAccountName = $result.properties.outputs.storageAccountName.value
    $storageAccountDfsEndpoint = $result.properties.outputs.storageAccountDfsEndpoint.value

    Write-Output "[EventHub]"
    Write-Output "Namespace = ""$eventHubNamespace"""
    Write-Output "Name = ""$eventHubName"""
    Write-Output "ServiceBusEndpoint = ""$serviceBusEndpoint"""

    Write-Output "[Storage]"
    Write-Output "AccountName = ""$storageAccountName"""
    Write-Output "DfsEndpoint = ""$storageAccountDfsEndpoint"""
}
catch {
    Write-Error "Failed to push containers: $_"
    Write-Error $_.ScriptStackTrace
    exit 1
}
