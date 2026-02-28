param(
    [Parameter(Mandatory=$true)]
    [string]
    $AppId
)

try {
    # Get today's date and time for the description
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $description = "Created on $timestamp"

    Write-Host "Creating app secret for App ID: $AppId" -ForegroundColor Cyan
    Write-Host "Description: $description" -ForegroundColor Cyan
    Write-Host ""

    # Create the app secret - use 'password add' instead of 'reset' to get the credential ID
    $secretJson = az ad app credential reset --id $AppId --display-name $description -o json
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create app secret."
    }

    $secretResult = $secretJson | ConvertFrom-Json
    $clientSecret = $secretResult.password
    
    # The credential reset command doesn't return keyId, so we need to query for credentials
    # and find the one matching our description
    $credsJson = az ad app credential list --id $AppId --query "[?displayName=='$description'].keyId" -o json
    if ($LASTEXITCODE -eq 0 -and $credsJson) {
        $creds = $credsJson | ConvertFrom-Json
        # Handle PowerShell array properly - if it's an array, get first element; if string, use as-is
        if ($creds -is [System.Array] -and $creds.Count -gt 0) {
            $secretId = $creds[0]
        } elseif ($creds -and $creds -isnot [System.Array]) {
            $secretId = $creds
        } else {
            $secretId = "Not available"
        }
    } else {
        $secretId = "Not available"
    }

    # Get the tenant ID from the current account
    $account = az account show --query "homeTenantId" -o tsv
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get tenant information."
    }

    # Output the configuration
    Write-Host "Please add the following to your config.toml:" -ForegroundColor Green
    Write-Host ""
    Write-Output "[Identity]"
    Write-Output "TenantId = ""$account"""
    Write-Output "AppId = ""$AppId"""
    Write-Output "AppSecret = ""$clientSecret"""
    Write-Output "# SecretId: $secretId"
}
catch {
    Write-Error "Failed to create app secret: $_"
    Write-Error $_.ScriptStackTrace
    exit 1
}
