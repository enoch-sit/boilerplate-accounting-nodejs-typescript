#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Completely rebuild all Docker containers with cache cleaning.

.DESCRIPTION
    This script stops all running containers, removes them, clears Docker cache,
    and rebuilds all containers from scratch to ensure a clean environment.

.PARAMETER DevOnly
    Only rebuild the development environment containers.

.PARAMETER TestOnly
    Only rebuild the test environment containers.

.PARAMETER SkipPull
    Skip pulling latest images from Docker Hub.

.PARAMETER Force
    Don't ask for confirmation before proceeding.

.EXAMPLE
    .\rebuild-docker.ps1

.EXAMPLE
    .\rebuild-docker.ps1 -DevOnly -Force

.NOTES
    Author: AuthSystem Team
    Date:   April 2025
#>

param (
    [switch]$DevOnly,
    [switch]$TestOnly,
    [switch]$SkipPull,
    [switch]$Force
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# Configure error handling
$ErrorActionPreference = "Stop"

# Display header
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  Docker Environment Complete Rebuild" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "This script will:"
Write-Host "  1. Stop all running containers"
Write-Host "  2. Remove all related containers"
Write-Host "  3. Remove related volumes (optional)"
Write-Host "  4. Clear Docker build cache"
Write-Host "  5. Rebuild all containers from scratch"

# Get confirmation unless Force is specified
if (-not $Force) {
    Write-Host "`nWARNING: This will remove all containers and potentially data." -ForegroundColor Yellow
    $confirmation = Read-Host "Do you want to continue? (y/n)"
    if ($confirmation -ne 'y') {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        exit
    }
}

# Determine which docker-compose files to use
$composeFiles = @()

if (-not $TestOnly) {
    $composeFiles += @("-f", "docker-compose.dev.yml") 
}

if (-not $DevOnly) {
    $composeFiles += @("-f", "docker-compose.mailhog-test.yml")
}

# Function to execute commands and handle errors
function Execute-Command {
    param (
        [string]$Description,
        [scriptblock]$Command
    )
    
    Write-Host "`n> $Description" -ForegroundColor Cyan
    try {
        & $Command
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Command failed with exit code: $LASTEXITCODE" -ForegroundColor Red
            return $false
        }
        return $true
    }
    catch {
        Write-Host "Error: $_" -ForegroundColor Red
        return $false
    }
}

# Step 1: Stop all running containers
if ($composeFiles.Count -gt 0) {
    Execute-Command -Description "Stopping all containers..." -Command {
        foreach ($file in $composeFiles) {
            if ($file -ne "-f") {
                Write-Host "Using compose file: $file" -ForegroundColor Gray
            }
        }
        docker-compose $composeFiles down
    }
}

# Step 2: Remove all related containers (including stopped ones)
Execute-Command -Description "Removing related containers..." -Command {
    # Find containers related to our services
    $containers = docker ps -a --filter "name=auth-service" --filter "name=mongodb" --filter "name=mailhog" -q
    if ($containers) {
        docker rm -f $containers
    } else {
        Write-Host "No matching containers found to remove" -ForegroundColor Yellow
    }
}

# Step 3: Optional - Remove volumes
$removeVolumes = $false
if (-not $Force) {
    $volumeConfirmation = Read-Host "Do you want to remove related volumes? This will DELETE ALL DATA. (y/n)"
    $removeVolumes = $volumeConfirmation -eq 'y'
} else {
    # In force mode, don't remove volumes by default for safety
    $removeVolumes = $false
}

if ($removeVolumes) {
    Execute-Command -Description "Removing related volumes..." -Command {
        # Find volumes related to our services
        $volumes = docker volume ls --filter "name=mongodb" -q
        if ($volumes) {
            docker volume rm $volumes
        } else {
            Write-Host "No matching volumes found to remove" -ForegroundColor Yellow
        }
    }
}

# Step 4: Clear Docker build cache
Execute-Command -Description "Clearing Docker build cache..." -Command {
    # Use system prune to clear build cache, but don't remove all unused images to avoid re-downloading everything
    docker builder prune -f
}

# Step 5: Pull latest images (unless skipped)
if (-not $SkipPull) {
    Execute-Command -Description "Pulling latest base images..." -Command {
        # Pull necessary base images
        docker pull node:18
        docker pull mongo:latest
        docker pull mailhog/mailhog:latest
    }
}

# Step 6: Rebuild and start containers
if ($composeFiles.Count -gt 0) {
    Execute-Command -Description "Rebuilding and starting containers..." -Command {
        docker-compose $composeFiles up -d --build --force-recreate
    }
}

# Step 7: Verify that everything is running
Execute-Command -Description "Verifying containers status..." -Command {
    $healthCheck = Join-Path $scriptRoot "docker-health-check.ps1"
    if (Test-Path $healthCheck) {
        & $healthCheck
    } else {
        Write-Host "Health check script not found at: $healthCheck" -ForegroundColor Yellow
        docker ps
    }
}

Write-Host "`n===============================================" -ForegroundColor Cyan
Write-Host "  Docker Environment Rebuild Complete" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan