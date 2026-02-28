<#
.SYNOPSIS
    Start the Docker containers using Docker Compose.

.DESCRIPTION
    This script starts the Docker containers using the docker-compose.yml
    file located in the docker directory. It runs in attached mode (not detached)
    so you can watch the logs in real-time and stop the containers with Ctrl-C.

.EXAMPLE
    .\Start-Containers.ps1
    Starts the containers and displays logs in the console.

.NOTES
    Press Ctrl-C to stop the containers.
#>

[CmdletBinding()]
param()

# Get script location and set paths
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptPath
$dockerPath = Join-Path $projectRoot "docker"
$composeFile = Join-Path $dockerPath "docker-compose.yml"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Starting Docker Containers" -ForegroundColor Cyan
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
Write-Host "Starting containers (attached mode - press Ctrl-C to stop)..." -ForegroundColor Cyan
Write-Host "Command: docker compose -f `"$composeFile`" up" -ForegroundColor Gray
Write-Host ""

# Execute docker compose up (not detached)
try {
    docker compose -f $composeFile up
    
    # This will only be reached if the user stops the containers (Ctrl-C)
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Yellow
    Write-Host "Containers stopped" -ForegroundColor Yellow
    Write-Host "==================================================" -ForegroundColor Yellow
} catch {
    Write-Host ""
    Write-Host "✗ Failed to start containers: $_" -ForegroundColor Red
    exit 1
}
