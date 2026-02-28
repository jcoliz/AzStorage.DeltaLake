<#
.SYNOPSIS
    Build the SyntheticTH Docker container using Docker Compose.

.DESCRIPTION
    This script builds the SyntheticTH Docker container using the docker-compose.yml
    file located in the docker directory. It supports various build options and
    provides verbose output.

.PARAMETER NoBuildCache
    Build without using cache from previous builds.

.PARAMETER Pull
    Always attempt to pull a newer version of the base image.

.PARAMETER Parallel
    Build images in parallel (default is sequential).

.PARAMETER DetailedOutput
    Show detailed build output.

.EXAMPLE
    .\Build-Containers.ps1
    Builds the container using cached layers if available.

.EXAMPLE
    .\Build-Containers.ps1 -NoBuildCache
    Builds the container without using any cached layers.

.EXAMPLE
    .\Build-Containers.ps1 -Pull -DetailedOutput
    Pulls latest base images and shows detailed build output.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$NoBuildCache,

    [Parameter(Mandatory=$false)]
    [switch]$Pull,

    [Parameter(Mandatory=$false)]
    [switch]$Parallel,

    [Parameter(Mandatory=$false)]
    [switch]$DetailedOutput
)

# Get script location and set paths
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptPath
$dockerPath = Join-Path $projectRoot "docker"
$composeFile = Join-Path $dockerPath "docker-compose.yml"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Building All Docker Containers" -ForegroundColor Cyan
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
$composeArgs = @("compose", "-f", $composeFile, "build")

if ($NoBuildCache) {
    $composeArgs += "--no-cache"
    Write-Host "→ Building without cache" -ForegroundColor Yellow
}

if ($Pull) {
    $composeArgs += "--pull"
    Write-Host "→ Pulling latest base images" -ForegroundColor Yellow
}

if ($Parallel) {
    $composeArgs += "--parallel"
    Write-Host "→ Building images in parallel" -ForegroundColor Yellow
}

if ($DetailedOutput) {
    $composeArgs += "--progress=plain"
    Write-Host "→ Detailed output enabled" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Building container..." -ForegroundColor Cyan
Write-Host "Command: docker $($composeArgs -join ' ')" -ForegroundColor Gray
Write-Host ""

# Execute the build
$startTime = Get-Date
try {
    & docker $composeArgs
    
    if ($LASTEXITCODE -eq 0) {
        $endTime = Get-Date
        $duration = $endTime - $startTime
        Write-Host ""
        Write-Host "==================================================" -ForegroundColor Green
        Write-Host "✓ Build completed successfully!" -ForegroundColor Green
        Write-Host "Duration: $($duration.ToString('mm\:ss'))" -ForegroundColor Green
        Write-Host "==================================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "To start the container, run:" -ForegroundColor Cyan
        Write-Host "  cd docker" -ForegroundColor White
        Write-Host "  docker compose up -d" -ForegroundColor White
        Write-Host ""
        Write-Host "To view logs, run:" -ForegroundColor Cyan
        Write-Host "  docker compose logs -f" -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "✗ Build failed with exit code: $LASTEXITCODE" -ForegroundColor Red
        exit $LASTEXITCODE
    }
} catch {
    Write-Host ""
    Write-Host "✗ Build failed with error: $_" -ForegroundColor Red
    exit 1
}
