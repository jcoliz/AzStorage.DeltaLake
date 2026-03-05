<#
.SYNOPSIS
    Push the Docker containers to a container registry using Docker Compose.

.DESCRIPTION
    This script pushes the Docker containers defined in docker-compose.yml
    to a container registry. Ensure you are logged in to your container registry
    before running this script (use 'docker login' or 'az acr login').

.PARAMETER Service
    Optionally specify a specific service to push. If not specified, all services will be pushed.

.EXAMPLE
    .\Push-Containers.ps1
    Pushes all container images defined in docker-compose.yml.

.EXAMPLE
    .\Push-Containers.ps1 -Service synthetich
    Pushes only the synthetich service container image.

.NOTES
    Ensure you are authenticated to your container registry before running:
    - For Azure Container Registry: az acr login --name <registry-name>
    - For Docker Hub: docker login
    - For other registries: docker login <registry-url>
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$Service
)

# Get script location and set paths
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptPath
$dockerPath = Join-Path $projectRoot "docker"
$composeFile = Join-Path $dockerPath "docker-compose.yml"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Pushing Docker Containers" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Check if Docker is installed
try {
    $dockerVersion = docker --version
    Write-Host "✓ Docker found: $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Docker is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Docker Desktop from https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    exit 1
}

# Check if Docker Compose is available
try {
    $composeVersion = docker compose version
    Write-Host "✓ Docker Compose found: $composeVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Docker Compose is not available" -ForegroundColor Red
    exit 1
}

# Check if docker-compose.yml exists
if (-not (Test-Path $composeFile)) {
    Write-Host "✗ docker-compose.yml not found at: $composeFile" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Compose file found: $composeFile" -ForegroundColor Green
Write-Host ""

# Build docker compose command
$composeArgs = @("compose", "-f", $composeFile, "push")

if ($Service) {
    $composeArgs += $Service
    Write-Host "→ Pushing only service: $Service" -ForegroundColor Yellow
} else {
    Write-Host "→ Pushing all services" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Pushing container images..." -ForegroundColor Cyan
Write-Host "Command: docker $($composeArgs -join ' ')" -ForegroundColor Gray
Write-Host ""
Write-Host "Note: Ensure you are logged in to your container registry!" -ForegroundColor Yellow
Write-Host ""

# Execute the push
$startTime = Get-Date
try {
    & docker $composeArgs
    
    if ($LASTEXITCODE -eq 0) {
        $endTime = Get-Date
        $duration = $endTime - $startTime
        Write-Host ""
        Write-Host "==================================================" -ForegroundColor Green
        Write-Host "✓ Push completed successfully!" -ForegroundColor Green
        Write-Host "Duration: $($duration.ToString('mm\:ss'))" -ForegroundColor Green
        Write-Host "==================================================" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "✗ Push failed with exit code: $LASTEXITCODE" -ForegroundColor Red
        Write-Host ""
        Write-Host "Common issues:" -ForegroundColor Yellow
        Write-Host "  • Not logged in to container registry" -ForegroundColor White
        Write-Host "  • Insufficient permissions" -ForegroundColor White
        Write-Host "  • Image not built yet (run Build-Containers.ps1 first)" -ForegroundColor White
        Write-Host "  • Network connectivity issues" -ForegroundColor White
        exit $LASTEXITCODE
    }
} catch {
    Write-Host ""
    Write-Host "✗ Push failed with error: $_" -ForegroundColor Red
    exit 1
}
